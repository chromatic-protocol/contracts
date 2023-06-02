// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IUSUMLiquidity} from "@usum/core/interfaces/market/IUSUMLiquidity.sol";
import {LpSlot, LpSlotLib} from "@usum/core/external/lpslot/LpSlot.sol";
import {PositionParam} from "@usum/core/external/lpslot/PositionParam.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotMargin} from "@usum/core/libraries/LpSlotMargin.sol";
import {Errors} from "@usum/core/libraries/Errors.sol";

/**
 * @title LpSlotSet
 * @notice Represents a collection of long and short liquidity slots
 */
struct LpSlotSet {
    mapping(uint16 => LpSlot) _longSlots;
    mapping(uint16 => LpSlot) _shortSlots;
}

using LpSlotSetLib for LpSlotSet global;

/**
 * @title LpSlotSetLib
 * @notice Library for managing liquidity slots in an LPSlotSet
 */
library LpSlotSetLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;
    using LpSlotLib for LpSlot;

    /**
     * @notice Emitted when earning is accumulated for a liquidity slot.
     * @param feeRate The fee rate of the slot.
     * @param slotType The type of the slot ("L" for long, "S" for short).
     * @param earning The accumulated earning.
     */
    event LpSlotEarningAccumulated(
        uint16 indexed feeRate,
        bytes1 indexed slotType,
        uint256 indexed earning
    );

    uint256 private constant FEE_RATES_LENGTH = 36;
    uint16 private constant MIN_FEE_RATE = 1;

    struct _proportionalPositionParamValue {
        int256 leveragedQty;
        uint256 takerMargin;
    }

    /**
     * @notice Modifier to validate the trading fee rate.
     * @param tradingFeeRate The trading fee rate to validate.
     */
    modifier _validTradingFeeRate(int16 tradingFeeRate) {
        validateTradingFeeRate(tradingFeeRate);

        _;
    }

    /**
     * @notice Initializes the LpSlotSet.
     * @param self The reference to the LpSlotSet.
     */
    function initialize(LpSlotSet storage self) external {
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();
        for (uint256 i = 0; i < FEE_RATES_LENGTH; i++) {
            uint16 feeRate = _tradingFeeRates[i];
            self._longSlots[feeRate].initialize(int16(feeRate));
            self._shortSlots[feeRate].initialize(-int16(feeRate));
        }
    }

    /**
     * @notice Settles the liquidity slots in the LpSlotSet.
     * @param self The reference to the LpSlotSet.
     * @param ctx The LpContext object.
     */
    function settle(LpSlotSet storage self, LpContext memory ctx) external {
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();
        for (uint256 i = 0; i < FEE_RATES_LENGTH; i++) {
            uint16 feeRate = _tradingFeeRates[i];
            self._longSlots[feeRate].settle(ctx);
            self._shortSlots[feeRate].settle(ctx);
        }
    }

    /**
     * @notice Prepares slot margins based on the given quantity and maker margin.
     * @dev This function prepares slot margins by performing the following steps:
     *      1. Calculates the appropriate slot margins
     *         for each trading fee rate based on the provided quantity and maker margin.
     *      2. Iterates through the target slots based on the quantity,
     *         finds the minimum available fee rate,
     *         and determines the upper bound for calculating slot margins.
     *      3. Iterates from the minimum fee rate until the upper bound,
     *         assigning the remaining maker margin to the slots until it is exhausted.
     *      4. Creates an array of LpSlotMargin structs
     *         containing the trading fee rate and corresponding margin amount for each slot.
     * @param self The reference to the LpSlotSet.
     * @param qty The quantity of the position.
     * @param makerMargin The maker margin of the position.
     * @return slotMargins An array of LpSlotMargin representing the calculated slot margins.
     */
    function prepareSlotMargins(
        LpSlotSet storage self,
        int224 qty,
        uint256 makerMargin
    ) external view returns (LpSlotMargin[] memory) {
        // Retrieve the target liquidity slots based on the position quantity
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, qty);

        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();
        uint256[FEE_RATES_LENGTH] memory _slotMargins;

        uint256 to;
        uint256 cnt;
        uint256 remain = makerMargin;
        for (; to < FEE_RATES_LENGTH; to++) {
            if (remain == 0) break;

            uint256 freeLiquidity = _slots[_tradingFeeRates[to]].freeLiquidity();
            if (freeLiquidity > 0) {
                if (remain <= freeLiquidity) {
                    _slotMargins[to] = remain;
                    remain = 0;
                } else {
                    _slotMargins[to] = freeLiquidity;
                    remain -= freeLiquidity;
                }
                cnt++;
            }
        }

        require(remain == 0, Errors.NOT_ENOUGH_SLOT_FREE_LIQUIDITY);

        LpSlotMargin[] memory slotMargins = new LpSlotMargin[](cnt);
        for ((uint256 i, uint256 idx) = (0, 0); i < to; i++) {
            if (_slotMargins[i] > 0) {
                slotMargins[idx] = LpSlotMargin({
                    tradingFeeRate: _tradingFeeRates[i],
                    amount: _slotMargins[i]
                });
                unchecked {
                    idx++;
                }
            }
        }

        return slotMargins;
    }

    /**
     * @notice Accepts an open position and opens corresponding liquidity slots.
     * @dev This function calculates the target liquidity slots based on the position quantity.
     *      It prepares the slot margins and divides the position parameters accordingly.
     *      Then, it opens the liquidity slots with the corresponding parameters and trading fees.
     * @param self The reference to the LpSlotSet storage.
     * @param ctx The LpContext object.
     * @param position The Position object representing the open position.
     */
    function acceptOpenPosition(
        LpSlotSet storage self,
        LpContext memory ctx,
        Position memory position
    ) external {
        // Retrieve the target liquidity slots based on the position quantity
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, position.qty);

        uint256 makerMargin = position.makerMargin();
        LpSlotMargin[] memory slotMargins = position.slotMargins();

        // Divide the position parameters to match the slot margins
        _proportionalPositionParamValue[] memory paramValues = divideToPositionParamValue(
            position.leveragedQty(ctx),
            makerMargin,
            position.takerMargin,
            slotMargins
        );

        PositionParam memory param = newPositionParam(position.openVersion, position.openTimestamp);
        for (uint256 i = 0; i < slotMargins.length; i++) {
            LpSlotMargin memory slotMargin = slotMargins[i];

            if (slotMargin.amount > 0) {
                param.leveragedQty = paramValues[i].leveragedQty;
                param.takerMargin = paramValues[i].takerMargin;
                param.makerMargin = slotMargin.amount;

                _slots[slotMargins[i].tradingFeeRate].openPosition(
                    ctx,
                    param,
                    slotMargin.tradingFee()
                );
            }
        }
    }

    /**
     * @notice Accepts a close position request and closes the corresponding liquidity slots.
     * @dev This function calculates the target liquidity slots based on the position quantity.
     *      It retrieves the maker margin and slot margins from the position.
     *      Then, it divides the position parameters to match the slot margins.
     *      Finally, it closes the liquidity slots with the provided parameters.
     * @param self The reference to the LpSlotSet storage.
     * @param ctx The LpContext object.
     * @param position The Position object representing the close position request.
     */
    function acceptClosePosition(
        LpSlotSet storage self,
        LpContext memory ctx,
        Position memory position
    ) external {
        // Retrieve the target liquidity slots based on the position quantity
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, position.qty);

        uint256 makerMargin = position.makerMargin();
        LpSlotMargin[] memory slotMargins = position.slotMargins();

        // Divide the position parameters to match the slot margins
        _proportionalPositionParamValue[] memory paramValues = divideToPositionParamValue(
            position.leveragedQty(ctx),
            makerMargin,
            position.takerMargin,
            slotMargins
        );

        PositionParam memory param = newPositionParam(
            position.openVersion,
            position.closeVersion,
            position.openTimestamp,
            position.closeTimestamp
        );

        for (uint256 i = 0; i < slotMargins.length; i++) {
            if (slotMargins[i].amount > 0) {
                LpSlot storage _slot = _slots[slotMargins[i].tradingFeeRate];

                param.leveragedQty = paramValues[i].leveragedQty;
                param.takerMargin = paramValues[i].takerMargin;
                param.makerMargin = slotMargins[i].amount;

                _slot.closePosition(ctx, param);
            }
        }
    }

    /**
     * @notice Accepts a claim position request and processes the corresponding liquidity slots
     *         based on the realized position pnl.
     * @dev This function verifies if the absolute value of the realized position pnl is within the acceptable margin range.
     *      It retrieves the target liquidity slots based on the position quantity and the slot margins from the position.
     *      Then, it divides the position parameters to match the slot margins.
     *      Depending on the value of the realized position pnl, it either claims the position fully or partially.
     *      The claimed pnl is distributed among the liquidity slots according to their respective margins.
     * @param self The reference to the LpSlotSet storage.
     * @param ctx The LpContext object.
     * @param position The Position object representing the position to claim.
     * @param realizedPnl The realized position pnl (taker side).
     */
    function acceptClaimPosition(
        LpSlotSet storage self,
        LpContext memory ctx,
        Position memory position,
        int256 realizedPnl // realized position pnl (taker side)
    ) external {
        uint256 absRealizedPnl = realizedPnl.abs();
        uint256 makerMargin = position.makerMargin();
        // Ensure that the realized position pnl is within the acceptable margin range
        require(
            !((realizedPnl > 0 && absRealizedPnl > makerMargin) ||
                (realizedPnl < 0 && absRealizedPnl > position.takerMargin)),
            Errors.EXCEED_MARGIN_RANGE
        );

        // Retrieve the target liquidity slots based on the position quantity
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, position.qty);
        LpSlotMargin[] memory slotMargins = position.slotMargins();

        // Divide the position parameters to match the slot margins
        _proportionalPositionParamValue[] memory paramValues = divideToPositionParamValue(
            position.leveragedQty(ctx),
            makerMargin,
            position.takerMargin,
            slotMargins
        );

        PositionParam memory param = newPositionParam(
            position.openVersion,
            position.closeVersion,
            position.openTimestamp,
            position.closeTimestamp
        );

        if (realizedPnl == 0) {
            for (uint256 i = 0; i < slotMargins.length; i++) {
                if (slotMargins[i].amount > 0) {
                    LpSlot storage _slot = _slots[slotMargins[i].tradingFeeRate];

                    param.leveragedQty = paramValues[i].leveragedQty;
                    param.takerMargin = paramValues[i].takerMargin;
                    param.makerMargin = slotMargins[i].amount;

                    _slot.claimPosition(ctx, param, 0);
                }
            }
        } else if (realizedPnl > 0 && absRealizedPnl == makerMargin) {
            for (uint256 i = 0; i < slotMargins.length; i++) {
                if (slotMargins[i].amount > 0) {
                    LpSlot storage _slot = _slots[slotMargins[i].tradingFeeRate];

                    param.leveragedQty = paramValues[i].leveragedQty;
                    param.takerMargin = paramValues[i].takerMargin;
                    param.makerMargin = slotMargins[i].amount;

                    _slot.claimPosition(ctx, param, param.makerMargin.toInt256());
                }
            }
        } else {
            uint256 remainMakerMargin = makerMargin;
            uint256 remainRealizedPnl = absRealizedPnl;

            for (uint256 i = 0; i < slotMargins.length; i++) {
                if (slotMargins[i].amount > 0) {
                    LpSlot storage _slot = _slots[slotMargins[i].tradingFeeRate];

                    param.leveragedQty = paramValues[i].leveragedQty;
                    param.takerMargin = paramValues[i].takerMargin;
                    param.makerMargin = slotMargins[i].amount;

                    uint256 absTakerPnl = remainRealizedPnl.mulDiv(
                        param.makerMargin,
                        remainMakerMargin
                    );
                    if (realizedPnl < 0) {
                        // maker profit
                        absTakerPnl = Math.min(absTakerPnl, param.takerMargin);
                    } else {
                        // taker profit
                        absTakerPnl = Math.min(absTakerPnl, param.makerMargin);
                    }

                    int256 takerPnl = realizedPnl < 0
                        ? -(absTakerPnl.toInt256())
                        : absTakerPnl.toInt256();

                    _slot.claimPosition(ctx, param, takerPnl);

                    remainMakerMargin -= param.makerMargin;
                    remainRealizedPnl -= absTakerPnl;
                }
            }

            require(remainRealizedPnl == 0, Errors.EXCEED_MARGIN_RANGE);
        }
    }

    /**
     * @notice Accepts an add liquidity request
     *         and processes the liquidity slot corresponding to the given trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the acceptAddLiquidity function on the target liquidity slot.
     * @param self The reference to the LpSlotSet storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity slot.
     * @param amount The amount of liquidity to add.
     */
    function acceptAddLiquidity(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 amount
    ) external _validTradingFeeRate(tradingFeeRate) {
        // Retrieve the liquidity slot based on the trading fee rate
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        // Process the add liquidity request on the liquidity slot
        slot.acceptAddLiquidity(ctx, amount);
    }

    /**
     * @notice Accepts a claim liquidity request
     *         and processes the liquidity slot corresponding to the given trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the acceptClaimLiquidity function on the target liquidity slot.
     * @param self The reference to the LpSlotSet storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity slot.
     * @param amount The amount of liquidity to claim.
     *        (should be the same as the one used in acceptAddLiquidity)
     * @param oracleVersion The oracle version used for the claim.
     *        (should be the oracle version when call acceptAddLiquidity)
     * @return The amount of liquidity (LP tokens) received as a result of the liquidity claim.
     */
    function acceptClaimLiquidity(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 amount,
        uint256 oracleVersion
    ) external _validTradingFeeRate(tradingFeeRate) returns (uint256) {
        // Retrieve the liquidity slot based on the trading fee rate
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        // Process the claim liquidity request on the liquidity slot and return the actual claimed amount
        return slot.acceptClaimLiquidity(ctx, amount, oracleVersion);
    }

    /**
     * @notice Accepts a remove liquidity request
     *         and processes the liquidity slot corresponding to the given trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the acceptRemoveLiquidity function on the target liquidity slot.
     * @param self The reference to the LpSlotSet storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity slot.
     * @param lpTokenAmount The amount of LP tokens to remove.
     */
    function acceptRemoveLiquidity(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 lpTokenAmount
    ) external _validTradingFeeRate(tradingFeeRate) {
        // Retrieve the liquidity slot based on the trading fee rate
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        // Process the remove liquidity request on the liquidity slot
        slot.acceptRemoveLiquidity(ctx, lpTokenAmount);
    }

    /**
     * @notice Accepts a withdraw liquidity request
     *         and processes the liquidity slot corresponding to the given trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the acceptWithdrawLiquidity function on the target liquidity slot.
     * @param self The reference to the LpSlotSet storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity slot.
     * @param lpTokenAmount The amount of LP tokens to withdraw.
     *        (should be the same as the one used in acceptRemoveLiquidity)
     * @param oracleVersion The oracle version used for the withdrawal.
     *        (should be the oracle version when call acceptRemoveLiquidity)
     * @return amount The amount of base tokens withdrawn
     * @return burnedLpTokenAmount the amount of LP tokens burned.
     */
    function acceptWithdrawLiquidity(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 lpTokenAmount,
        uint256 oracleVersion
    )
        external
        _validTradingFeeRate(tradingFeeRate)
        returns (uint256 amount, uint256 burnedLpTokenAmount)
    {
        // Retrieve the liquidity slot based on the trading fee rate
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        // Process the withdraw liquidity request on the liquidity slot
        // and get the amount of base tokens withdrawn and LP tokens burned
        return slot.acceptWithdrawLiquidity(ctx, lpTokenAmount, oracleVersion);
    }

    /**
     * @notice Calculates the amount of LP tokens to be minted for the given amount of base tokens and trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the calculateLpTokenMinting function on the target liquidity slot.
     * @param self The reference to the LpSlotSet storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity slot.
     * @param amount The amount of base tokens.
     * @return The amount of LP tokens to be minted.
     */
    function calculateLpTokenMinting(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 amount
    ) external view _validTradingFeeRate(tradingFeeRate) returns (uint256) {
        // Retrieve the liquidity slot based on the trading fee rate
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        // Calculate the amount of LP tokens to be minted based on the given amount of base tokens
        return slot.calculateLpTokenMinting(ctx, amount);
    }

    /**
     * @notice Calculates the value of the given amount of LP tokens for the specified trading fee rate.
     * @dev This function validates the trading fee rate
     *      and calls the calculateLpTokenValue function on the target liquidity slot.
     * @param self The reference to the LpSlotSet storage.
     * @param ctx The LpContext object.
     * @param tradingFeeRate The trading fee rate associated with the liquidity slot.
     * @param lpTokenAmount The amount of LP tokens.
     * @return amount The value of the LP tokens in base tokens.
     */
    function calculateLpTokenValue(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 lpTokenAmount
    ) external view _validTradingFeeRate(tradingFeeRate) returns (uint256 amount) {
        // Retrieve the liquidity slot based on the trading fee rate
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        // Calculate the value of the given amount of LP tokens in base tokens
        amount = slot.calculateLpTokenValue(ctx, lpTokenAmount);
    }

    /**
     * @notice Retrieves the total liquidity amount in base tokens for the specified trading fee rate.
     * @dev This function retrieves the liquidity slot based on the trading fee rate
     *      and calls the liquidity function on it.
     * @param self The reference to the LpSlotSet storage.
     * @param tradingFeeRate The trading fee rate associated with the liquidity slot.
     * @return amount The total liquidity amount in base tokens.
     */
    function getSlotLiquidity(
        LpSlotSet storage self,
        int16 tradingFeeRate
    ) external view returns (uint256 amount) {
        // Retrieve the liquidity slot based on the trading fee rate
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        // Get the total liquidity amount in base tokens from the liquidity slot
        return slot.liquidity();
    }

    /**
     * @notice Retrieves the free liquidity amount in base tokens for the specified trading fee rate.
     * @dev This function retrieves the liquidity slot based on the trading fee rate
     *      and calls the freeLiquidity function on it.
     * @param self The reference to the LpSlotSet storage.
     * @param tradingFeeRate The trading fee rate associated with the liquidity slot.
     * @return amount The free liquidity amount in base tokens.
     */
    function getSlotFreeLiquidity(
        LpSlotSet storage self,
        int16 tradingFeeRate
    ) external view returns (uint256 amount) {
        // Retrieve the liquidity slot based on the trading fee rate
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        // Get the free liquidity amount in base tokens from the liquidity slot
        return slot.freeLiquidity();
    }

    /**
     * @notice Retrieves the target slots based on the sign of the given value.
     * @dev This function retrieves the target slots mapping (short or long) based on the sign of the given value.
     * @param self The storage reference to the LpSlotSet.
     * @param sign The sign of the value (-1 for negative, 1 for positive).
     * @return _slots The target slots mapping associated with the sign of the value.
     */
    function targetSlots(
        LpSlotSet storage self,
        int256 sign
    ) private view returns (mapping(uint16 => LpSlot) storage) {
        return sign < 0 ? self._shortSlots : self._longSlots;
    }

    /**
     * @notice Retrieves the target slot based on the trading fee rate.
     * @dev This function retrieves the target slot based on the sign of the trading fee rate and returns it.
     * @param self The storage reference to the LpSlotSet.
     * @param tradingFeeRate The trading fee rate associated with the slot.
     * @return slot The target slot associated with the trading fee rate.
     */
    function targetSlot(
        LpSlotSet storage self,
        int16 tradingFeeRate
    ) private view returns (LpSlot storage) {
        return
            tradingFeeRate < 0
                ? self._shortSlots[abs(tradingFeeRate)]
                : self._longSlots[abs(tradingFeeRate)];
    }

    /**
     * @notice Divides the leveraged quantity, maker margin, and taker margin
     *         into proportional position parameter values.
     * @dev This function divides the leveraged quantity, maker margin, and taker margin
     *      into proportional position parameter values based on the slot margins.
     *      It calculates the proportional values for each slot margin and returns them in an array.
     * @param leveragedQty The leveraged quantity.
     * @param makerMargin The maker margin amount.
     * @param takerMargin The taker margin amount.
     * @param slotMargins The array of slot margins.
     * @return values The array of proportional position parameter values.
     */
    function divideToPositionParamValue(
        int256 leveragedQty,
        uint256 makerMargin,
        uint256 takerMargin,
        LpSlotMargin[] memory slotMargins
    ) private pure returns (_proportionalPositionParamValue[] memory) {
        uint256 remainLeveragedQty = leveragedQty.abs();
        uint256 remainTakerMargin = takerMargin;

        _proportionalPositionParamValue[] memory values = new _proportionalPositionParamValue[](
            slotMargins.length
        );

        for (uint256 i = 0; i < slotMargins.length - 1; i++) {
            uint256 _qty = remainLeveragedQty.mulDiv(slotMargins[i].amount, makerMargin);
            uint256 _takerMargin = remainTakerMargin.mulDiv(slotMargins[i].amount, makerMargin);

            values[i] = _proportionalPositionParamValue({
                leveragedQty: leveragedQty < 0 ? _qty.toInt256() : -(_qty.toInt256()), // opposit side
                takerMargin: _takerMargin
            });

            remainLeveragedQty -= _qty;
            remainTakerMargin -= _takerMargin;
        }

        values[slotMargins.length - 1] = _proportionalPositionParamValue({
            leveragedQty: leveragedQty < 0
                ? remainLeveragedQty.toInt256()
                : -(remainLeveragedQty.toInt256()), // opposit side
            takerMargin: remainTakerMargin
        });

        return values;
    }

    /**
     * @notice Creates a new PositionParam struct with the given oracle version and timestamp.
     * @param openVersion The version of the oracle when the position was opened
     * @param openTimestamp The timestamp when the position was opened
     * @return param The new PositionParam struct.
     */
    function newPositionParam(
        uint256 openVersion,
        uint256 openTimestamp
    ) private pure returns (PositionParam memory param) {
        param.openVersion = openVersion;
        param.openTimestamp = openTimestamp;
    }

    /**
     * @notice Creates a new PositionParam struct with the given oracle version and timestamp.
     * @param openVersion The version of the oracle when the position was opened
     * @param closeVersion The version of the oracle when the position was closed
     * @param openTimestamp The timestamp when the position was opened
     * @param closeTimestamp The timestamp when the position was closed
     * @return param The new PositionParam struct.
     */
    function newPositionParam(
        uint256 openVersion,
        uint256 closeVersion,
        uint256 openTimestamp,
        uint256 closeTimestamp
    ) private pure returns (PositionParam memory param) {
        param.openVersion = openVersion;
        param.closeVersion = closeVersion;
        param.openTimestamp = openTimestamp;
        param.closeTimestamp = closeTimestamp;
    }

    /**
     * @notice Validates the trading fee rate.
     * @dev This function validates the trading fee rate by checking if it is supported.
     *      It compares the absolute value of the fee rate with the predefined trading fee rates
     *      to determine if it is a valid rate.
     * @param tradingFeeRate The trading fee rate to be validated.
     */
    function validateTradingFeeRate(int16 tradingFeeRate) private pure {
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();

        uint16 absFeeRate = abs(tradingFeeRate);

        uint256 idx = findUpperBound(_tradingFeeRates, absFeeRate);
        require(
            idx < _tradingFeeRates.length && absFeeRate == _tradingFeeRates[idx],
            Errors.UNSUPPORTED_TRADING_FEE_RATE
        );
    }

    /**
     * @notice Calculates the absolute value of an int16 number.
     * @param i The int16 number.
     * @return absValue The absolute value of the input number.
     */
    function abs(int16 i) private pure returns (uint16) {
        return i < 0 ? uint16(-i) : uint16(i);
    }

    /**
     * @notice Retrieves the array of supported trading fee rates.
     * @dev This function returns the array of supported trading fee rates,
     *      ranging from the minimum fee rate to the maximum fee rate with step increments.
     * @return tradingFeeRates The array of supported trading fee rates.
     */
    function tradingFeeRates() private pure returns (uint16[FEE_RATES_LENGTH] memory) {
        // prettier-ignore
        return [
            MIN_FEE_RATE, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
            10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
            100, 200, 300, 400, 500, 600, 700, 800, 900, // 1% ~ 9%, step 1%
            1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
        ];
    }

    /**
     * @notice Finds the upper bound index of an element in a sorted array.
     * @dev This function performs a binary search on the sorted array
     *      to find * the index of the upper bound of the given element.
     *      It returns the index as the exclusive upper bound,
     *      or the inclusive upper bound if the element is found at the end of the array.
     * @param array The sorted array.
     * @param element The element to find the upper bound for.
     * @return uint256 The index of the upper bound of the element in the array.
     */
    function findUpperBound(
        uint16[FEE_RATES_LENGTH] memory array,
        uint16 element
    ) private pure returns (uint256) {
        if (array.length == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = Math.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds down (it does integer division with truncation).
            if (array[mid] > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && array[low - 1] == element) {
            return low - 1;
        } else {
            return low;
        }
    }

    /**
     * @notice Distributes earnings among the liquidity slots.
     * @dev This function distributes the earnings among the liquidity slots,
     *      proportional to their total balances.
     *      It iterates through the trading fee rates
     *      and distributes the proportional amount of earnings to each slot
     *      based on its total balance relative to the market balance.
     * @param self The LpSlotSet storage.
     * @param earning The total earnings to be distributed.
     * @param marketBalance The market balance.
     */
    function distributeEarning(
        LpSlotSet storage self,
        uint256 earning,
        uint256 marketBalance
    ) external {
        uint256 remainEarning = earning;
        uint256 remainBalance = marketBalance;
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();

        (remainEarning, remainBalance) = distributeEarning(
            self._longSlots,
            remainEarning,
            remainBalance,
            _tradingFeeRates,
            "L"
        );
        (remainEarning, remainBalance) = distributeEarning(
            self._shortSlots,
            remainEarning,
            remainBalance,
            _tradingFeeRates,
            "S"
        );
    }

    /**
     * @notice Distributes earnings among the liquidity slots of a specific type.
     * @dev This function distributes the earnings among the liquidity slots of
     *      the specified type, proportional to their total balances.
     *      It iterates through the trading fee rates
     *      and distributes the proportional amount of earnings to each slot
     *      based on its total balance relative to the market balance.
     * @param lpSlots The liquidity slots mapping.
     * @param earning The total earnings to be distributed.
     * @param marketBalance The market balance.
     * @param _tradingFeeRates The array of supported trading fee rates.
     * @param slotType The type of liquidity slot ("L" for long, "S" for short).
     * @return remainEarning The remaining earnings after distribution.
     * @return remainBalance The remaining market balance after distribution.
     */
    function distributeEarning(
        mapping(uint16 => LpSlot) storage lpSlots,
        uint256 earning,
        uint256 marketBalance,
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates,
        bytes1 slotType
    ) private returns (uint256 remainEarning, uint256 remainBalance) {
        remainBalance = marketBalance;
        remainEarning = earning;

        for (uint256 i = 0; i < FEE_RATES_LENGTH; i++) {
            uint16 feeRate = _tradingFeeRates[i];
            LpSlot storage slot = lpSlots[feeRate];
            uint256 slotLiquidity = slot.liquidity();

            if (slotLiquidity == 0) continue;

            uint256 slotEarning = remainEarning.mulDiv(slotLiquidity, remainBalance);

            slot.applyEarning(slotEarning);

            remainBalance -= slotLiquidity;
            remainEarning -= slotEarning;

            emit LpSlotEarningAccumulated(feeRate, slotType, slotEarning);
        }
    }
}
