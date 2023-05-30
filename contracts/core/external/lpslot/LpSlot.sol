// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {SignedMath} from '@openzeppelin/contracts/utils/math/SignedMath.sol';
import {LpSlotPosition, LpSlotPositionLib} from '@usum/core/external/lpslot/LpSlotPosition.sol';
import {LpSlotClosedPosition, LpSlotClosedPositionLib} from '@usum/core/external/lpslot/LpSlotClosedPosition.sol';
import {PositionParam} from '@usum/core/external/lpslot/PositionParam.sol';
import {LpContext} from '@usum/core/libraries/LpContext.sol';
import {LpTokenLib} from '@usum/core/libraries/LpTokenLib.sol';
import {Errors} from '@usum/core/libraries/Errors.sol';

struct LpSlot {
    uint256 lpTokenId;
    uint256 total;
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
    using LpSlotPositionLib for LpSlotPosition;
    using LpSlotClosedPositionLib for LpSlotClosedPosition;

    /// @dev Minimum amount constant to prevent division by zero.
    uint256 private constant MIN_AMOUNT = 1000;

    /**
     * @notice Modifier to settle accrued interest and pending positions before executing a function.
     * @param self The LpSlot storage.
     * @param ctx The LpContext data struct.
     */
    modifier _settle(LpSlot storage self, LpContext memory ctx) {
        self._closedPosition.settleAccruedInterest(ctx);
        self._closedPosition.settleClosingPosition(ctx);
        self._position.settleAccruedInterest(ctx);
        self._position.settlePendingPosition(ctx);

        _;
    }

    function initialize(LpSlot storage self, int16 tradingFeeRate) internal {
        self.lpTokenId = LpTokenLib.encodeId(tradingFeeRate);
    }

    /**
     * @notice Opens a new liquidity position in the slot.
     * @dev This function validates the maker margin against the available balance in the slot
     *      and opens the position using the specified parameters.
     *      Additionally, it increments the total by the trading fee amount.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param param The PositionParam memory.
     * @param tradingFee The trading fee amount.
     */
    function openPosition(
        LpSlot storage self,
        LpContext memory ctx,
        PositionParam memory param,
        uint256 tradingFee
    ) internal _settle(self, ctx) {
        require(param.makerMargin <= self.freeLiquidity(), Errors.NOT_ENOUGH_SLOT_FREE_LIQUIDITY);

        self._position.onOpenPosition(param);
        self.total += tradingFee;
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
            self.total += absTakerPnl;
        } else {
            self.total -= absTakerPnl;
        }
    }

    function freeLiquidity(LpSlot storage self) internal view returns (uint256) {
        return self.total - self._position.totalMakerMargin();
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

        uint256 _value = unrealizedPnl < 0 ? self.total - absPnl : self.total + absPnl;
        return _value + ctx.market.vault().getPendingSlotShare(address(ctx.market), self.total);
    }

    /**
     * @notice Adds liquidity to the slot.
     * @dev If there is no existing liquidity in the pool, the entire amount is considered as liquidity.
     *      Otherwise, the LP token amount is calculated based on the current slot value
     *      and the total supplied LP token.
     *      The total amount is then incremented by the added liquidity.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param amount The amount of liquidity to add.
     * @param lpTokenTotalSupply The total supplied LP token.
     * @return lpTokenAmount The amount of LP token to be minted.
     */
    function addLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount,
        uint256 lpTokenTotalSupply
    ) internal _settle(self, ctx) returns (uint256 lpTokenAmount) {
        require(amount > MIN_AMOUNT, Errors.TOO_SMALL_AMOUNT);

        lpTokenAmount = self.calculateLiquidity(ctx, amount, lpTokenTotalSupply);

        self.total += amount;
    }

    function calculateLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount,
        uint256 lpTokenTotalSupply
    ) internal view returns (uint256 lpTokenAmount) {
        if (lpTokenTotalSupply == 0) {
            lpTokenAmount = amount;
        } else {
            uint256 slotValue = self.value(ctx);
            lpTokenAmount = amount.mulDiv(lpTokenTotalSupply, slotValue < MIN_AMOUNT ? MIN_AMOUNT : slotValue);
        }
    }

    function removeLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 lpTokenAmount,
        uint256 lpTokenTotalSupply
    ) internal _settle(self, ctx) returns (uint256 amount) {
        amount = self.calculateAmount(ctx, lpTokenAmount, lpTokenTotalSupply);
        require(amount <= self.freeLiquidity(), Errors.NOT_ENOUGH_SLOT_FREE_LIQUIDITY);

        self.total -= amount;
    }

    function calculateAmount(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 lpTokenAmount,
        uint256 lpTokenTotalSupply
    ) internal view returns (uint256 amount) {
        amount = lpTokenAmount.mulDiv(self.value(ctx), lpTokenTotalSupply);
    }
}
