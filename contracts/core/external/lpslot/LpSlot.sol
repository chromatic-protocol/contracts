// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {LpSlotPosition, LpSlotPositionLib} from "@usum/core/external/lpslot/LpSlotPosition.sol";
import {PositionParam} from "@usum/core/external/lpslot/PositionParam.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {Errors} from "@usum/core/libraries/Errors.sol";

struct LpSlot {
    uint256 total;
    LpSlotPosition _position;
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

    /// @dev Minimum amount constant to prevent division by zero.
    uint256 private constant MIN_AMOUNT = 1000;

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
    ) internal {
        require(
            param.makerMargin <= self.balance(),
            Errors.NOT_ENOUGH_SLOT_BALANCE
        );

        self._position.openPosition(ctx, param);
        self.total += tradingFee;
    }

    /**
     * @notice Closes an existing liquidity position in the slot.
     * @dev This function closes the position using the specified parameters
     *      and updates the total by subtracting the absolute value
     *      of the taker's profit or loss (takerPnl) from it.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param param The PositionParam memory.
     * @param takerPnl The taker's profit/loss.
     */
    function closePosition(
        LpSlot storage self,
        LpContext memory ctx,
        PositionParam memory param,
        int256 takerPnl
    ) internal {
        self._position.closePosition(ctx, param);

        uint256 absTakerPnl = takerPnl.abs();
        if (takerPnl < 0) {
            self.total += absTakerPnl;
        } else {
            self.total -= absTakerPnl;
        }
    }

    /**
     * @notice Calculates the balance of the slot.
     * @dev This function subtracts the total maker margin held in the slot position from the total balance.
     * @param self The LpSlot storage.
     * @return uint256 The balance of the slot.
     */
    function balance(LpSlot storage self) internal view returns (uint256) {
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
    function value(
        LpSlot storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        int256 unrealizedPnl = self._position.unrealizedPnl(ctx);
        uint256 absPnl = unrealizedPnl.abs();

        uint256 _value = unrealizedPnl < 0
            ? self.total - absPnl
            : self.total + absPnl;
        return
            _value +
            ctx.market.vault().getPendingSlotShare(
                address(ctx.market),
                self.total
            );
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
     * @param totalLiquidity The total supplied LP token.
     * @return liquidity The amount of LP token to be minted.
     */
    function addLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 amount,
        uint256 totalLiquidity
    ) internal returns (uint256 liquidity) {
        require(amount > MIN_AMOUNT, Errors.TOO_SMALL_AMOUNT);

        if (totalLiquidity == 0) {
            liquidity = amount;
        } else {
            uint256 slotValue = self.value(ctx);
            liquidity = amount.mulDiv(
                totalLiquidity,
                slotValue < MIN_AMOUNT ? MIN_AMOUNT : slotValue
            );
        }

        self.total += amount;
    }

    /**
     * @notice Removes liquidity from the slot.
     * @dev The liquidity amount is calculated based on the current slot value
     *      and the total supplied LP token.
     *      The amount of liquidity removed is returned,
     *      and the total amount is decremented by the removed liquidity.
     *      It also checks if the resulting balance is sufficient.
     * @param self The LpSlot storage.
     * @param ctx The LpContext memory.
     * @param liquidity The amount of LP token to be burned.
     * @param totalLiquidity The total supplied LP token.
     * @return amount The amount of liquidity removed.
     */
    function removeLiquidity(
        LpSlot storage self,
        LpContext memory ctx,
        uint256 liquidity,
        uint256 totalLiquidity
    ) internal returns (uint256 amount) {
        amount = liquidity.mulDiv(self.value(ctx), totalLiquidity);
        require(amount <= self.balance(), Errors.NOT_ENOUGH_SLOT_BALANCE);

        self.total -= amount;
    }
}
