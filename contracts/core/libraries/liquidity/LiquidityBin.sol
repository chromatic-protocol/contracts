// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IMarketLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidity.sol";
import {BinLiquidity, BinLiquidityLib} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinLiquidity.sol";
import {BinPosition, BinPositionLib} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinPosition.sol";
import {BinClosedPosition, BinClosedPositionLib} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinClosedPosition.sol";
import {PositionParam} from "@chromatic-protocol/contracts/core/libraries/liquidity/PositionParam.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {Errors} from "@chromatic-protocol/contracts/core/libraries/Errors.sol";

/**
 * @dev Structure representing a liquidity bin
 * @param clbTokenId The ID of the CLB token
 * @param _liquidity The liquidity data for the bin
 * @param _position The position data for the bin
 * @param _closedPosition The closed position data for the bin
 */
struct LiquidityBin {
    uint256 clbTokenId;
    BinLiquidity _liquidity;
    BinPosition _position;
    BinClosedPosition _closedPosition;
    mapping(uint256 => IMarketLiquidity.LiquidityBinValue) binValueAt; // oracleVersion => binValue
}

/**
 * @title LiquidityBinLib
 * @notice Library for managing liquidity bin
 */
library LiquidityBinLib {
    using Math for uint256;
    using SignedMath for int256;
    using LiquidityBinLib for LiquidityBin;
    using BinLiquidityLib for BinLiquidity;
    using BinPositionLib for BinPosition;
    using BinClosedPositionLib for BinClosedPosition;

    /**
     * @notice Modifier to settle the pending positions, closing positions,
     *         and pending liquidity of the bin before executing a function.
     * @param self The LiquidityBin storage.
     * @param ctx The LpContext data struct.
     */
    modifier _settle(LiquidityBin storage self, LpContext memory ctx) {
        self.settle(ctx);
        _;
    }

    /**
     * @notice Settles the pending positions, closing positions, and pending liquidity of the bin.
     * @param self The LiquidityBin storage.
     * @param ctx The LpContext data struct.
     */
    function settle(LiquidityBin storage self, LpContext memory ctx) internal {
        self._closedPosition.settleClosingPosition(ctx);
        self._position.settlePendingPosition(ctx);
        if (self._liquidity.needSettle(ctx)) {
            uint256 binValue = self.value(ctx);
            uint256 clbTokenId = self.clbTokenId;
            uint256 totalSupply = ctx.clbToken.totalSupply(clbTokenId);

            uint256 oracleVersion = ctx.currentOracleVersion().version;
            self.binValueAt[oracleVersion] = IMarketLiquidity.LiquidityBinValue({
                binValue: binValue,
                clbTokenTotalSupply: totalSupply
            });

            self._liquidity.settlePendingLiquidity(
                ctx,
                binValue,
                self.freeLiquidity(),
                clbTokenId,
                totalSupply
            );
        }
    }

    /**
     * @notice Initializes the liquidity bin with the given trading fee rate
     * @param self The LiquidityBin storage
     * @param tradingFeeRate The trading fee rate to set
     */
    function initialize(LiquidityBin storage self, int16 tradingFeeRate) internal {
        self.clbTokenId = CLBTokenLib.encodeId(tradingFeeRate);
    }

    /**
     * @notice Opens a new position in the liquidity bin
     * @dev Throws an error with the code `Errors.NOT_ENOUGH_FREE_LIQUIDITY` if there is not enough free liquidity.
     * @param self The LiquidityBin storage
     * @param ctx The LpContext data struct
     * @param param The position parameters
     * @param tradingFee The trading fee amount
     */
    function openPosition(
        LiquidityBin storage self,
        LpContext memory ctx,
        PositionParam memory param,
        uint256 tradingFee
    ) internal {
        require(param.makerMargin <= self.freeLiquidity(), Errors.NOT_ENOUGH_FREE_LIQUIDITY);

        self._position.onOpenPosition(ctx, param);
        self._liquidity.total += tradingFee;
    }

    /**
     * @notice Closes a position in the liquidity bin
     * @param self The LiquidityBin storage
     * @param ctx The LpContext data struct
     * @param param The position parameters
     */
    function closePosition(
        LiquidityBin storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal _settle(self, ctx) {
        self._position.onClosePosition(ctx, param);
        if (param.closeVersion > param.openVersion) {
            self._closedPosition.onClosePosition(ctx, param);
        }
    }

    /**
     * @notice Claims an existing liquidity position in the bin.
     * @dev This function claims the position using the specified parameters
     *      and updates the total by subtracting the absolute value
     *      of the taker's profit or loss (takerPnl) from it.
     * @param self The LiquidityBin storage.
     * @param ctx The LpContext memory.
     * @param param The PositionParam memory.
     * @param takerPnl The taker's profit/loss.
     */
    function claimPosition(
        LiquidityBin storage self,
        LpContext memory ctx,
        PositionParam memory param,
        int256 takerPnl
    ) internal _settle(self, ctx) {
        if (param.closeVersion == 0) {
            // called when liquidate
            self._position.onClosePosition(ctx, param);
        } else if (param.closeVersion > param.openVersion) {
            self._closedPosition.onClaimPosition(ctx, param);
        }

        uint256 absTakerPnl = takerPnl.abs();
        if (takerPnl < 0) {
            self._liquidity.total += absTakerPnl;
        } else {
            self._liquidity.total -= absTakerPnl;
        }
    }

    /**
     * @notice Retrieves the total liquidity in the bin
     * @param self The LiquidityBin storage
     * @return uint256 The total liquidity in the bin
     */
    function liquidity(LiquidityBin storage self) internal view returns (uint256) {
        return self._liquidity.total;
    }

    /**
     * @notice Retrieves the free liquidity in the bin (liquidity minus total maker margin)
     * @param self The LiquidityBin storage
     * @return uint256 The free liquidity in the bin
     */
    function freeLiquidity(LiquidityBin storage self) internal view returns (uint256) {
        return
            self._liquidity.total -
            self._position.totalMakerMargin() -
            self._closedPosition.totalMakerMargin();
    }

    /**
     * @notice Applies earnings to the liquidity bin
     * @param self The LiquidityBin storage
     * @param earning The earning amount to apply
     */
    function applyEarning(LiquidityBin storage self, uint256 earning) internal {
        self._liquidity.total += earning;
    }

    /**
     * @notice Calculates the value of the bin.
     * @dev This function considers the unrealized profit or loss of the position
     *      and adds it to the total value.
     *      Additionally, it includes the pending bin share from the market's vault.
     * @param self The LiquidityBin storage.
     * @param ctx The LpContext memory.
     * @return uint256 The value of the bin.
     */
    function value(
        LiquidityBin storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        int256 unrealizedPnl = self._position.unrealizedPnl(ctx);

        uint256 absPnl = unrealizedPnl.abs();

        uint256 _liquidity = self.liquidity();
        uint256 _value = unrealizedPnl < 0 ? _liquidity - absPnl : _liquidity + absPnl;
        return
            _value +
            self._closedPosition.currentInterest(ctx) +
            ctx.vault.getPendingBinShare(ctx.market, ctx.settlementToken, _liquidity);
    }

    /**
     * @notice Accepts an add liquidity request.
     * @dev This function adds liquidity to the bin by calling the `onAddLiquidity` function
     *      of the liquidity component.
     * @param self The LiquidityBin storage.
     * @param ctx The LpContext memory.
     * @param amount The amount of liquidity to add.
     */
    function acceptAddLiquidity(
        LiquidityBin storage self,
        LpContext memory ctx,
        uint256 amount
    ) internal _settle(self, ctx) {
        self._liquidity.onAddLiquidity(amount, ctx.currentOracleVersion().version);
    }

    /**
     * @notice Accepts a claim liquidity request.
     * @dev This function claims liquidity from the bin by calling the `onClaimLiquidity` function
     *      of the liquidity component.
     * @param self The LiquidityBin storage.
     * @param ctx The LpContext memory.
     * @param amount The amount of liquidity to claim.
     *        (should be the same as the one used in acceptAddLiquidity)
     * @param oracleVersion The oracle version used for the claim.
     *        (should be the oracle version when call acceptAddLiquidity)
     * @return The amount of liquidity (CLB tokens) received as a result of the liquidity claim.
     */
    function acceptClaimLiquidity(
        LiquidityBin storage self,
        LpContext memory ctx,
        uint256 amount,
        uint256 oracleVersion
    ) internal _settle(self, ctx) returns (uint256) {
        return self._liquidity.onClaimLiquidity(amount, oracleVersion);
    }

    /**
     * @notice Accepts a remove liquidity request.
     * @dev This function removes liquidity from the bin by calling the `onRemoveLiquidity` function
     *      of the liquidity component.
     * @param self The LiquidityBin storage.
     * @param ctx The LpContext memory.
     * @param clbTokenAmount The amount of CLB tokens to remove.
     */
    function acceptRemoveLiquidity(
        LiquidityBin storage self,
        LpContext memory ctx,
        uint256 clbTokenAmount
    ) internal _settle(self, ctx) {
        self._liquidity.onRemoveLiquidity(clbTokenAmount, ctx.currentOracleVersion().version);
    }

    /**
     * @notice Accepts a withdraw liquidity request.
     * @dev This function withdraws liquidity from the bin by calling the `onWithdrawLiquidity` function
     *      of the liquidity component.
     * @param self The LiquidityBin storage.
     * @param ctx The LpContext memory.
     * @param clbTokenAmount The amount of CLB tokens to withdraw.
     *        (should be the same as the one used in acceptRemoveLiquidity)
     * @param oracleVersion The oracle version used for the withdrawal.
     *        (should be the oracle version when call acceptRemoveLiquidity)
     * @return amount The amount of liquidity withdrawn
     * @return burnedCLBTokenAmount The amount of CLB tokens burned during the withdrawal.
     */
    function acceptWithdrawLiquidity(
        LiquidityBin storage self,
        LpContext memory ctx,
        uint256 clbTokenAmount,
        uint256 oracleVersion
    ) internal _settle(self, ctx) returns (uint256 amount, uint256 burnedCLBTokenAmount) {
        (amount, burnedCLBTokenAmount) = self._liquidity.onWithdrawLiquidity(
            clbTokenAmount,
            oracleVersion
        );
    }

    /**
     * @dev Retrieves the pending liquidity information from a LiquidityBin.
     * @param self The reference to the LiquidityBin struct.
     * @return pendingLiquidity An instance of IMarketLiquidity.PendingLiquidity representing the pending liquidity information.
     */
    function pendingLiquidity(
        LiquidityBin storage self
    ) internal view returns (IMarketLiquidity.PendingLiquidity memory) {
        return self._liquidity.pendingLiquidity();
    }

    /**
     * @dev Retrieves the claimable liquidity information for a specific oracle version from a LiquidityBin.
     * @param self The reference to the LiquidityBin struct.
     * @param oracleVersion The oracle version for which to retrieve the claimable liquidity.
     * @return claimableLiquidity An instance of IMarketLiquidity.ClaimableLiquidity representing the claimable liquidity information.
     */
    function claimableLiquidity(
        LiquidityBin storage self,
        uint256 oracleVersion
    ) internal view returns (IMarketLiquidity.ClaimableLiquidity memory) {
        return self._liquidity.claimableLiquidity(oracleVersion);
    }
}
