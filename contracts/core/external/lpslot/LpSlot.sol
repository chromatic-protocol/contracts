// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {LpSlotLiquidity, LpSlotLiquidityLib} from "@usum/core/external/lpslot/LpSlotLiquidity.sol";
import {LpSlotPosition, LpSlotPositionLib} from "@usum/core/external/lpslot/LpSlotPosition.sol";
import {LpSlotClosedPosition, LpSlotClosedPositionLib} from "@usum/core/external/lpslot/LpSlotClosedPosition.sol";
import {PositionParam} from "@usum/core/external/lpslot/PositionParam.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpTokenLib} from "@usum/core/libraries/LpTokenLib.sol";
import {Errors} from "@usum/core/libraries/Errors.sol";

struct LpSlot {
    uint256 lpTokenId;
    LpSlotLiquidity _liquidity;
    LpSlotPosition _position;
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
     * @notice Modifier to settle accrued interest and pending positions before executing a function.
     * @param self The LpSlot storage.
     * @param ctx The LpContext data struct.
     */
    modifier _settle(LpSlot storage self, LpContext memory ctx) {
        self.settle(ctx);
        _;
    }

    function settle(LpSlot storage self, LpContext memory ctx) internal {
        self._closedPosition.settleAccruedInterest(ctx);
        self._closedPosition.settleClosingPosition(ctx);
        self._position.settleAccruedInterest(ctx);
        self._position.settlePendingPosition(ctx);
        self._liquidity.settlePendingLiquidity(
            ctx,
            self.value(ctx),
            self.freeLiquidity(),
            self.lpTokenId
        );
    }

    function initialize(LpSlot storage self, int16 tradingFeeRate) internal {
        self.lpTokenId = LpTokenLib.encodeId(tradingFeeRate);
    }

    function openPosition(
        LpSlot storage self,
        LpContext memory ctx,
        PositionParam memory param,
        uint256 tradingFee
    ) internal _settle(self, ctx) {
        require(param.makerMargin <= self.freeLiquidity(), Errors.NOT_ENOUGH_SLOT_FREE_LIQUIDITY);

        self._position.onOpenPosition(param);
        self._liquidity.total += tradingFee;
    }

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

    function liquidity(LpSlot storage self) internal view returns (uint256) {
        return self._liquidity.total;
    }

    function freeLiquidity(LpSlot storage self) internal view returns (uint256) {
        return self._liquidity.total - self._position.totalMakerMargin();
    }

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
        return _value + ctx.vault.getPendingSlotShare(address(ctx.market), _liquidity);
    }

    function acceptAddLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount
    ) internal _settle(self, ctx) {
        self._liquidity.onAddLiquidity(amount, ctx.currentOracleVersion().version);
    }

    function acceptClaimLpToken(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount,
        uint256 oracleVersion
    ) internal _settle(self, ctx) returns (uint256) {
        return self._liquidity.onClaimLpToken(amount, oracleVersion);
    }

    function calculateLpTokenMinting(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount
    ) internal view returns (uint256) {
        return
            LpSlotLiquidityLib.calculateLpTokenMinting(
                amount,
                self.value(ctx),
                ctx.lpToken.totalSupply(self.lpTokenId)
            );
    }

    function removeLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 lpTokenAmount
    ) internal _settle(self, ctx) returns (uint256 amount) {
        amount = self.calculateLpTokenValue(ctx, lpTokenAmount);
        require(amount <= self.freeLiquidity(), Errors.NOT_ENOUGH_SLOT_FREE_LIQUIDITY);

        self._liquidity.total -= amount;
    }

    function calculateLpTokenValue(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 lpTokenAmount
    ) internal view returns (uint256) {
        return
            LpSlotLiquidityLib.calculateLpTokenValue(
                lpTokenAmount,
                self.value(ctx),
                ctx.lpToken.totalSupply(self.lpTokenId)
            );
    }
}
