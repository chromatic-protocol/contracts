// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {SignedMath} from '@openzeppelin/contracts/utils/math/SignedMath.sol';
import {IUSUMLiquidity} from '@usum/core/interfaces/market/IUSUMLiquidity.sol';
import {LpSlot, LpSlotLib} from '@usum/core/external/lpslot/LpSlot.sol';
import {PositionParam} from '@usum/core/external/lpslot/PositionParam.sol';
import {Position} from '@usum/core/libraries/Position.sol';
import {LpContext} from '@usum/core/libraries/LpContext.sol';
import {LpSlotMargin} from '@usum/core/libraries/LpSlotMargin.sol';
import {Errors} from '@usum/core/libraries/Errors.sol';

struct LpSlotSet {
    uint16 _minAvailableFeeRateLong;
    uint16 _minAvailableFeeRateShort;
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
    event LpSlotEarningAccumulated(uint16 indexed feeRate, bytes1 slotType, uint256 earning);

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
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, qty);

        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();
        uint256[FEE_RATES_LENGTH] memory _slotMargins;

        uint16 _minFeeRate = minAvailableFeeRate(self, qty);

        uint256 from = findUpperBound(_tradingFeeRates, _minFeeRate);
        uint256 to = from;
        uint256 remain = makerMargin;
        for (; to < FEE_RATES_LENGTH; to++) {
            if (remain == 0) break;

            uint256 freeLiquidity = _slots[_tradingFeeRates[to]].freeLiquidity();
            if (remain <= freeLiquidity) {
                _slotMargins[to] = remain;
                remain = 0;
            } else {
                _slotMargins[to] = freeLiquidity;
                remain -= freeLiquidity;
            }
        }

        require(remain == 0, Errors.NOT_ENOUGH_SLOT_FREE_LIQUIDITY);

        LpSlotMargin[] memory slotMargins = new LpSlotMargin[](to - from);
        for (uint256 i = from; i < to; i++) {
            slotMargins[i - from] = LpSlotMargin({tradingFeeRate: _tradingFeeRates[i], amount: _slotMargins[i]});
        }

        return slotMargins;
    }

    /**
     * @notice Accepts an open position and updates the liquidity slots accordingly.
     * @dev This function accepts an open position by performing the following steps:
     *      1. Retrieves the target slots based on the position's quantity.
     *      2. Obtains the maker margin and slot margins from the position.
     *      3. Divides the leveraged quantity, maker margin, taker margin,
     *         and slot margins into proportional position parameter values.
     *      4. Creates a new PositionParam memory with the oracle version and timestamp from the position.
     *      5. Iterates through the slot margins and processes the open position
     *         for each non-zero slot margin amount.
     *         - Sets the leveraged quantity, taker margin, and maker margin in the PositionParam.
     *         - Calls the openPosition function on the corresponding slot,
     *           passing the LpContext, PositionParam, and trading fee from the slot margin.
     *      6. Sets the minimum available fee rate in the LpSlotSet
     *         based on the trading fee rate of the last slot margin.
     * @param self The reference to the LpSlotSet.
     * @param ctx The LpContext object.
     * @param position The Position object representing the open position.
     */
    function acceptOpenPosition(LpSlotSet storage self, LpContext memory ctx, Position memory position) external {
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, position.qty);

        uint256 makerMargin = position.makerMargin();
        LpSlotMargin[] memory slotMargins = position.slotMargins();

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

                _slots[slotMargins[i].tradingFeeRate].openPosition(ctx, param, slotMargin.tradingFee());
            }
        }

        setMinAvailableFeeRate(self, position, slotMargins[slotMargins.length - 1].tradingFeeRate);
    }

    function acceptClosePosition(LpSlotSet storage self, LpContext memory ctx, Position memory position) external {
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, position.qty);

        uint256 makerMargin = position.makerMargin();
        LpSlotMargin[] memory slotMargins = position.slotMargins();

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
     * @notice Accepts a claim position request and performs necessary operations.
     * @dev This function accepts a claim position by performing the following steps:
     *      1. Validates the provided realizedPnl against the position's maker and taker margins.
     *      2. Calculates the position parameter values for each slot
     *         based on the leveraged quantity, maker margin, taker margin, and slot margins.
     *      3. Calls the claimPosition function on each slot
     *         with the calculated parameters to claim the position.
     *         - If the realizedPnl is zero, it claims all slots with non-zero amounts.
     *         - If the realizedPnl is positive and equal to the maker margin,
     *           it claims all slots with non-zero amounts and sets the taker profit as the pnl for each slot.
     *         - Otherwise, it iterates through each slot and calculates the appropriate taker pnl
     *           based on the remaining realizedPnl and maker margin. This function then claims each slot
     *           with the calculated taker pnl.
     *      4. Updates the minimum available fee rate based on the slotMargins.
     * @dev This function throws an error if the realizedPnl exceeds the margin range.
     * @param self The storage reference to the LpSlotSet.
     * @param ctx The LpContext structure containing contextual information.
     * @param position The Position structure representing the position to be claimed.
     * @param realizedPnl The realized position profit/loss (taker side).
     */
    function acceptClaimPosition(
        LpSlotSet storage self,
        LpContext memory ctx,
        Position memory position,
        int256 realizedPnl // realized position pnl (taker side)
    ) external {
        uint256 absRealizedPnl = realizedPnl.abs();
        uint256 makerMargin = position.makerMargin();
        require(
            !((realizedPnl > 0 && absRealizedPnl > makerMargin) ||
                (realizedPnl < 0 && absRealizedPnl > position.takerMargin)),
            Errors.EXCEED_MARGIN_RANGE
        );

        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, position.qty);
        LpSlotMargin[] memory slotMargins = position.slotMargins();

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

                    uint256 absTakerPnl = remainRealizedPnl.mulDiv(param.makerMargin, remainMakerMargin);
                    if (realizedPnl < 0) {
                        // maker profit
                        absTakerPnl = Math.min(absTakerPnl, param.takerMargin);
                    } else {
                        // taker profit
                        absTakerPnl = Math.min(absTakerPnl, param.makerMargin);
                    }

                    int256 takerPnl = realizedPnl < 0 ? -(absTakerPnl.toInt256()) : absTakerPnl.toInt256();

                    _slot.claimPosition(ctx, param, takerPnl);

                    remainMakerMargin -= param.makerMargin;
                    remainRealizedPnl -= absTakerPnl;
                }
            }

            require(remainRealizedPnl == 0, Errors.EXCEED_MARGIN_RANGE);
        }

        uint16 _feeRate = slotMargins[0].tradingFeeRate;
        if (_feeRate < minAvailableFeeRate(self, position.qty)) {
            setMinAvailableFeeRate(self, position, _feeRate);
        }
    }

    /**
     * @notice Adds liquidity to the liquidity pool.
     * @dev This function adds liquidity to the liquidity pool by performing the following steps:
     *      1. Retrieves the target slot based on the trading fee rate.
     *      2. Calls the addLiquidity function on the target slot,
     *         passing the LpContext, amount, and lpTokenTotalSupply.
     *      3. Updates the minimum available fee rate if the trading fee rate is lower than the current minimum.
     * @param self The storage reference to the LpSlotSet.
     * @param ctx The LpContext memory containing the context information for the liquidity operation.
     * @param tradingFeeRate The trading fee rate associated with the liquidity being added.
     * @param amount The amount of liquidity being added.
     * @param lpTokenTotalSupply The total supplied LP token.
     * @return liquidity The amount of LP token to be minted.
     */
    function addLiquidity(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 amount,
        uint256 lpTokenTotalSupply
    ) external _validTradingFeeRate(tradingFeeRate) returns (uint256 liquidity) {
        LpSlot storage slot = targetSlot(self, tradingFeeRate);

        liquidity = slot.addLiquidity(ctx, amount, lpTokenTotalSupply);

        uint16 _feeRate = abs(tradingFeeRate);
        if (_feeRate < minAvailableFeeRate(self, tradingFeeRate)) {
            setMinAvailableFeeRate(self, tradingFeeRate);
        }
    }

    function calculateLiquidity(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 amount,
        uint256 lpTokenTotalSupply
    ) external view _validTradingFeeRate(tradingFeeRate) returns (uint256 lpTokenAmount) {
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        lpTokenAmount = slot.calculateLiquidity(ctx, amount, lpTokenTotalSupply);
    }

    /**
     * @notice Removes liquidity from the liquidity pool.
     * @dev This function removes liquidity from the liquidity pool by performing the following steps:
     *      1. Retrieves the target slot based on the trading fee rate.
     *      2. Calls the removeLiquidity function on the target slot,
     *         passing the LpContext, liquidity, and lpTokenTotalSupply.
     *      3. Returns the amount of liquidity that was removed.
     * @param self The storage reference to the LpSlotSet.
     * @param ctx The LpContext memory containing the context information for the liquidity operation.
     * @param tradingFeeRate The trading fee rate associated with the liquidity being removed.
     * @param lpTokenAmount The amount of LP token to be burned.
     * @param lpTokenTotalSupply The total supplied LP token.
     * @return amount The amount of liquidity that was removed.
     */
    function removeLiquidity(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 lpTokenAmount,
        uint256 lpTokenTotalSupply
    ) external _validTradingFeeRate(tradingFeeRate) returns (uint256 amount) {
        LpSlot storage slot = targetSlot(self, tradingFeeRate);

        amount = slot.removeLiquidity(ctx, lpTokenAmount, lpTokenTotalSupply);
    }

    function calculateAmount(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 lpTokenAmount,
        uint256 lpTokenTotalSupply
    ) external view _validTradingFeeRate(tradingFeeRate) returns (uint256 amount) {
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        amount = slot.calculateAmount(ctx, lpTokenAmount, lpTokenTotalSupply);
    }

    function getSlotLiquidity(LpSlotSet storage self, int16 tradingFeeRate) external view returns (uint256 amount) {
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        return slot.total;
    }

    function getSlotFreeLiquidity(LpSlotSet storage self, int16 tradingFeeRate) external view returns (uint256 amount) {
        LpSlot storage slot = targetSlot(self, tradingFeeRate);
        return slot.freeLiquidity();
    }

    /**
     * @notice Retrieves the target slots based on the sign of the given value.
     * @dev This function retrieves the target slots mapping (short or long) based on the sign of the given value.
     * @param self The storage reference to the LpSlotSet.
     * @param sign The sign of the value (-1 for negative, 1 for positive).
     * @return _slots The target slots mapping associated with the sign of the value.
     */
    function targetSlots(LpSlotSet storage self, int256 sign) private view returns (mapping(uint16 => LpSlot) storage) {
        return sign < 0 ? self._shortSlots : self._longSlots;
    }

    /**
     * @notice Retrieves the target slot based on the trading fee rate.
     * @dev This function retrieves the target slot based on the sign of the trading fee rate and returns it.
     * @param self The storage reference to the LpSlotSet.
     * @param tradingFeeRate The trading fee rate associated with the slot.
     * @return slot The target slot associated with the trading fee rate.
     */
    function targetSlot(LpSlotSet storage self, int16 tradingFeeRate) private view returns (LpSlot storage) {
        return tradingFeeRate < 0 ? self._shortSlots[abs(tradingFeeRate)] : self._longSlots[abs(tradingFeeRate)];
    }

    /**
     * @notice Retrieves the minimum available fee rate based on the sign of the given value.
     * @dev This function retrieves the minimum available fee rate based on the sign of the given value.
     *      If the fee rate is zero, it returns the minimum fee rate defined as MIN_FEE_RATE.
     * @param self The storage reference to the LpSlotSet.
     * @param sign The sign of the value (-1 for negative, 1 for positive).
     * @return feeRate The minimum available fee rate associated with the sign of the value.
     */
    function minAvailableFeeRate(LpSlotSet storage self, int256 sign) private view returns (uint16) {
        uint16 feeRate = sign < 0 ? self._minAvailableFeeRateShort : self._minAvailableFeeRateLong;
        return feeRate == 0 ? MIN_FEE_RATE : feeRate;
    }

    /**
     * @notice Sets the minimum available fee rate based on the position and fee rate.
     * @dev This function sets the minimum available fee rate based on the position and fee rate.
     *      If the position quantity is negative, it sets the fee rate
     *      as the minimum available fee rate for short positions.
     *      Otherwise, it sets the fee rate as the minimum available fee rate for long positions.
     * @param self The storage reference to the LpSlotSet.
     * @param position The position information.
     * @param feeRate The fee rate to be set as the minimum available fee rate.
     */
    function setMinAvailableFeeRate(LpSlotSet storage self, Position memory position, uint16 feeRate) private {
        if (position.qty < 0) {
            self._minAvailableFeeRateShort = feeRate;
        } else {
            self._minAvailableFeeRateLong = feeRate;
        }
    }

    /**
     * @notice Sets the minimum available fee rate based on the fee rate.
     * @dev This function sets the minimum available fee rate based on the fee rate.
     *      If the fee rate is negative, it sets the absolute value of the fee rate
     *      as the minimum available fee rate for short positions.
     *      Otherwise, it sets the fee rate as the minimum available fee rate for long positions.
     * @param self The storage reference to the LpSlotSet.
     * @param feeRate The fee rate to be set as the minimum available fee rate.
     */
    function setMinAvailableFeeRate(LpSlotSet storage self, int16 feeRate) private {
        if (feeRate < 0) {
            self._minAvailableFeeRateShort = abs(feeRate);
        } else {
            self._minAvailableFeeRateLong = abs(feeRate);
        }
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

        _proportionalPositionParamValue[] memory values = new _proportionalPositionParamValue[](slotMargins.length);

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
            leveragedQty: leveragedQty < 0 ? remainLeveragedQty.toInt256() : -(remainLeveragedQty.toInt256()), // opposit side
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
    function findUpperBound(uint16[FEE_RATES_LENGTH] memory array, uint16 element) private pure returns (uint256) {
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
    function distributeEarning(LpSlotSet storage self, uint256 earning, uint256 marketBalance) external {
        uint256 remainEarning = earning;
        uint256 remainBalance = marketBalance;
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();

        (remainEarning, remainBalance) = distributeEarning(
            self._longSlots,
            remainEarning,
            remainBalance,
            _tradingFeeRates,
            'L'
        );
        (remainEarning, remainBalance) = distributeEarning(
            self._shortSlots,
            remainEarning,
            remainBalance,
            _tradingFeeRates,
            'S'
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
            uint256 slotBalance = slot.total;

            if (slotBalance == 0) continue;

            uint256 slotEarning = remainEarning.mulDiv(slotBalance, remainBalance);

            slot.total += slotEarning;

            remainBalance -= slotBalance;
            remainEarning -= slotEarning;

            emit LpSlotEarningAccumulated(feeRate, slotType, slotEarning);
        }
    }
}
