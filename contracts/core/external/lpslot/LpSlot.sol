// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {LpSlotLiquidity, LpSlotLiquidityLib} from "@chromatic/core/external/lpslot/LpSlotLiquidity.sol";
import {LpSlotPosition, LpSlotPositionLib} from "@chromatic/core/external/lpslot/LpSlotPosition.sol";
import {LpSlotClosedPosition, LpSlotClosedPositionLib} from "@chromatic/core/external/lpslot/LpSlotClosedPosition.sol";
import {PositionParam} from "@chromatic/core/external/lpslot/PositionParam.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {CLBTokenLib} from "@chromatic/core/libraries/CLBTokenLib.sol";
import {Errors} from "@chromatic/core/libraries/Errors.sol";

/**
 * @title LpSlot
 * @notice Structure representing a liquidity slot
 */
struct LpSlot {
    /// @dev The ID of the CLB token
    uint256 clbTokenId;
    /// @dev The liquidity data for the slot
    LpSlotLiquidity _liquidity;
    /// @dev The position data for the slot
    LpSlotPosition _position;
    /// @dev The closed position data for the slot
    LpSlotClosedPosition _closedPosition;
}

/**
 * @title LpSlotLib
 * @notice Library for managing liquidity slot
 */
library LpSlotLib {
    using Math for uint256;
    using SignedMath for int256;
    using LpSlotLib for LpSlot;
    using LpSlotLiquidityLib for LpSlotLiquidity;
    using LpSlotPositionLib for LpSlotPosition;
    using LpSlotClosedPositionLib for LpSlotClosedPosition;

    /**
     * @notice Modifier to settle the pending positions, closing positions,
     *         and pending liquidity of the slot before executing a function.
     * @param self The LpSlot storage.
     * @param ctx The LpContext data struct.
     */
    modifier _settle(LpSlot storage self, LpContext memory ctx) {
        self.settle(ctx);
        _;
    }

    /**
     * @notice Settles the pending positions, closing positions, and pending liquidity of the slot.
     * @param self The LpSlot storage.
     * @param ctx The LpContext data struct.
     */
    function settle(LpSlot storage self, LpContext memory ctx) internal {
        self._closedPosition.settleClosingPosition(ctx);
        self._position.settlePendingPosition(ctx);
        self._liquidity.settlePendingLiquidity(
            ctx,
            self.value(ctx),
            self.freeLiquidity(),
            self.clbTokenId
        );
    }

    /**
     * @notice Initializes the liquidity slot with the given trading fee rate
     * @param self The LpSlot storage
     * @param tradingFeeRate The trading fee rate to set
     */
    function initialize(LpSlot storage self, int16 tradingFeeRate) internal {
        self.clbTokenId = CLBTokenLib.encodeId(tradingFeeRate);
    }

    /**
     * @notice Opens a new position in the liquidity slot
     * @param self The LpSlot storage
     * @param ctx The LpContext data struct
     * @param param The position parameters
     * @param tradingFee The trading fee amount
     */
    function openPosition(
        LpSlot storage self,
        LpContext memory ctx,
        PositionParam memory param,
        uint256 tradingFee
    ) internal _settle(self, ctx) {
        require(param.makerMargin <= self.freeLiquidity(), Errors.NOT_ENOUGH_SLOT_FREE_LIQUIDITY);

        self._position.onOpenPosition(ctx, param);
        self._liquidity.total += tradingFee;
    }

    /**
     * @notice Closes a position in the liquidity slot
     * @param self The LpSlot storage
     * @param ctx The LpContext data struct
     * @param param The position parameters
     */
    function closePosition(
        LpSlot storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal _settle(self, ctx) {
        self._position.onClosePosition(ctx, param);
        if (param.closeVersion > param.openVersion) {
            self._closedPosition.onClosePosition(ctx, param);
        }
    }

    /**
     * @notice Claims an existing liquidity position in the slot.
     * @dev This function claims the position using the specified parameters
     *      and updates the total by subtracting the absolute value
     *      of the taker's profit or loss (takerPnl) from it.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param param The PositionParam memory.
     * @param takerPnl The taker's profit/loss.
     */
    function claimPosition(
        LpSlot storage self,
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
     * @notice Retrieves the total liquidity in the slot
     * @param self The LpSlot storage
     * @return uint256 The total liquidity in the slot
     */
    function liquidity(LpSlot storage self) internal view returns (uint256) {
        return self._liquidity.total;
    }

    /**
     * @notice Retrieves the free liquidity in the slot (liquidity minus total maker margin)
     * @param self The LpSlot storage
     * @return uint256 The free liquidity in the slot
     */
    function freeLiquidity(LpSlot storage self) internal view returns (uint256) {
        return self._liquidity.total - self._position.totalMakerMargin();
    }

    /**
     * @notice Applies earnings to the liquidity slot
     * @param self The LpSlot storage
     * @param earning The earning amount to apply
     */
    function applyEarning(LpSlot storage self, uint256 earning) internal {
        self._liquidity.total += earning;
    }

    /**
     * @notice Calculates the value of the slot.
     * @dev This function considers the unrealized profit or loss of the position
     *      and adds it to the total value.
     *      Additionally, it includes the pending slot share from the market's vault.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @return uint256 The value of the slot.
     */
    function value(LpSlot storage self, LpContext memory ctx) internal view returns (uint256) {
        int256 unrealizedPnl = self._position.unrealizedPnl(ctx);
        uint256 absPnl = unrealizedPnl.abs();

        uint256 _liquidity = self.liquidity();
        uint256 _value = unrealizedPnl < 0 ? _liquidity - absPnl : _liquidity + absPnl;
        return _value + ctx.vault.getPendingSlotShare(ctx.market, _liquidity);
    }

    /**
     * @notice Accepts an add liquidity request.
     * @dev This function adds liquidity to the slot by calling the `onAddLiquidity` function
     *      of the liquidity component.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param amount The amount of liquidity to add.
     */
    function acceptAddLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount
    ) internal _settle(self, ctx) {
        self._liquidity.onAddLiquidity(amount, ctx.currentOracleVersion().version);
    }

    /**
     * @notice Accepts a claim liquidity request.
     * @dev This function claims liquidity from the slot by calling the `onClaimLiquidity` function
     *      of the liquidity component.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param amount The amount of liquidity to claim.
     *        (should be the same as the one used in acceptAddLiquidity)
     * @param oracleVersion The oracle version used for the claim.
     *        (should be the oracle version when call acceptAddLiquidity)
     * @return The amount of liquidity (CLB tokens) received as a result of the liquidity claim.
     */
    function acceptClaimLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount,
        uint256 oracleVersion
    ) internal _settle(self, ctx) returns (uint256) {
        return self._liquidity.onClaimLiquidity(amount, oracleVersion);
    }

    /**
     * @notice Accepts a remove liquidity request.
     * @dev This function removes liquidity from the slot by calling the `onRemoveLiquidity` function
     *      of the liquidity component.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param clbTokenAmount The amount of CLB tokens to remove.
     */
    function acceptRemoveLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 clbTokenAmount
    ) internal _settle(self, ctx) {
        self._liquidity.onRemoveLiquidity(clbTokenAmount, ctx.currentOracleVersion().version);
    }

    /**
     * @notice Accepts a withdraw liquidity request.
     * @dev This function withdraws liquidity from the slot by calling the `onWithdrawLiquidity` function
     *      of the liquidity component.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param clbTokenAmount The amount of CLB tokens to withdraw.
     *        (should be the same as the one used in acceptRemoveLiquidity)
     * @param oracleVersion The oracle version used for the withdrawal.
     *        (should be the oracle version when call acceptRemoveLiquidity)
     * @return amount The amount of liquidity withdrawn
     * @return burnedCLBTokenAmount The amount of CLB tokens burned during the withdrawal.
     */
    function acceptWithdrawLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 clbTokenAmount,
        uint256 oracleVersion
    ) internal _settle(self, ctx) returns (uint256 amount, uint256 burnedCLBTokenAmount) {
        return self._liquidity.onWithdrawLiquidity(clbTokenAmount, oracleVersion);
    }

    /**
     * @notice Calculates the amount of CLB tokens to be minted when adding liquidity.
     * @dev This function calculates the number of CLB tokens to be minted
     *      based on the specified amount of liquidity, the slot's current value, and the total supply of CLB tokens.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param amount The amount of liquidity to be added.
     * @return The amount of CLB tokens to be minted.
     */
    function calculateCLBTokenMinting(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount
    ) internal view returns (uint256) {
        return
            LpSlotLiquidityLib.calculateCLBTokenMinting(
                amount,
                self.value(ctx),
                ctx.clbToken.totalSupply(self.clbTokenId)
            );
    }

    /**
     * @notice Calculates the value of the specified amount of CLB tokens.
     * @dev This function calculates the value of the specified amount of CLB tokens
     *      based on the slot's current value and the total supply of CLB tokens.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param clbTokenAmount The amount of CLB tokens.
     * @return The value of the specified amount of CLB tokens.
     */
    function calculateCLBTokenValue(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 clbTokenAmount
    ) internal view returns (uint256) {
        return
            LpSlotLiquidityLib.calculateCLBTokenValue(
                clbTokenAmount,
                self.value(ctx),
                ctx.clbToken.totalSupply(self.clbTokenId)
            );
    }
}
