// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlot} from "@usum/core/libraries/LpSlot.sol";
import {LpSlotMargin} from "@usum/core/libraries/LpSlotMargin.sol";

struct LpSlotSet {
    uint16 _minAvailableFeeRateLong;
    uint16 _minAvailableFeeRateShort;
    mapping(uint16 => LpSlot) _longSlots;
    mapping(uint16 => LpSlot) _shortSlots;
}

using LpSlotSetLib for LpSlotSet global;

library LpSlotSetLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

    uint256 private constant FEE_RATES_LENGTH = 36;
    uint16 private constant MIN_FEE_RATE = 1;

    struct _proportionalPositionParamValue {
        int256 leveragedQty;
        uint256 takerMargin;
    }

    error NotEnoughSlotBalance();
    error ExceedMarginRange();
    error UnsupportedTradingFeeRate();

    modifier _validTradingFeeRate(int16 tradingFeeRate) {
        validateTradingFeeRate(tradingFeeRate);

        _;
    }

    function prepareSlotMargins(
        LpSlotSet storage self,
        Position memory position,
        uint256 makerMargin
    ) internal view {
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, position);

        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();
        uint256[FEE_RATES_LENGTH] memory _slotMargins;

        uint16 _minFeeRate = minAvailableFeeRate(self, position);

        uint256 from = findUpperBound(_tradingFeeRates, _minFeeRate);
        uint256 to = from;
        uint256 remain = makerMargin;
        for (; to < FEE_RATES_LENGTH; to++) {
            if (remain == 0) break;

            uint256 balance = _slots[_tradingFeeRates[to]].balance();
            if (remain <= balance) {
                _slotMargins[to] = remain;
                remain = 0;
            } else {
                _slotMargins[to] = balance;
                remain -= balance;
            }
        }

        if (remain > 0) revert NotEnoughSlotBalance();

        LpSlotMargin[] memory slotMargins = new LpSlotMargin[](to - from);
        for (uint256 i = from; i < to; i++) {
            slotMargins[i - from] = LpSlotMargin({
                tradingFeeRate: _tradingFeeRates[i],
                amount: _slotMargins[i]
            });
        }

        position.setSlotMargins(slotMargins);
    }

    function acceptOpenPosition(
        LpSlotSet storage self,
        LpContext memory ctx,
        Position memory position
    ) internal {
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, position);

        uint256 makerMargin = position.makerMargin();
        LpSlotMargin[] memory slotMargins = position.slotMargins();

        _proportionalPositionParamValue[]
            memory paramValues = divideToPositionParamValue(
                position.leveragedQty(ctx),
                makerMargin,
                position.takerMargin,
                slotMargins
            );

        PositionParam memory param = newPositionParam(
            position.oracleVersion,
            position.timestamp
        );
        for (uint256 i = 0; i < slotMargins.length; i++) {
            LpSlotMargin memory slotMargin = slotMargins[i];

            param.leveragedQty = paramValues[i].leveragedQty;
            param.takerMargin = paramValues[i].takerMargin;
            param.makerMargin = slotMargin.amount;

            _slots[slotMargins[i].tradingFeeRate].openPosition(
                ctx,
                param,
                slotMargin.tradingFee()
            );
        }

        setMinAvailableFeeRate(
            self,
            position,
            slotMargins[slotMargins.length - 1].tradingFeeRate
        );
    }

    function acceptClosePosition(
        LpSlotSet storage self,
        LpContext memory ctx,
        Position memory position,
        int256 realizedPnl // realized position pnl (taker side)
    ) internal {
        mapping(uint16 => LpSlot) storage _slots = targetSlots(self, position);

        uint256 makerMargin = position.makerMargin();
        LpSlotMargin[] memory slotMargins = position.slotMargins();

        _proportionalPositionParamValue[]
            memory paramValues = divideToPositionParamValue(
                position.leveragedQty(ctx),
                makerMargin,
                position.takerMargin,
                slotMargins
            );

        uint256 remainMakerMargin = makerMargin;
        uint256 remainRealizedPnl = realizedPnl.abs();
        PositionParam memory param = newPositionParam(
            position.oracleVersion,
            position.timestamp
        );
        for (uint256 i = 0; i < slotMargins.length; i++) {
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

            _slots[slotMargins[i].tradingFeeRate].closePosition(
                ctx,
                param,
                realizedPnl < 0
                    ? -(absTakerPnl.toInt256())
                    : absTakerPnl.toInt256()
            );

            remainMakerMargin -= param.makerMargin;
            remainRealizedPnl -= absTakerPnl;
        }

        if (remainRealizedPnl != 0) {
            revert ExceedMarginRange();
        }

        uint16 _feeRate = slotMargins[0].tradingFeeRate;
        if (_feeRate < minAvailableFeeRate(self, position)) {
            setMinAvailableFeeRate(self, position, _feeRate);
        }
    }

    function mint(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 amount,
        uint256 totalLiquidity
    )
        internal
        _validTradingFeeRate(tradingFeeRate)
        returns (uint256 liquidity)
    {
        LpSlot storage slot = targetSlot(self, tradingFeeRate);

        liquidity = slot.mint(ctx, amount, totalLiquidity);

        uint16 _feeRate = abs(tradingFeeRate);
        if (_feeRate < minAvailableFeeRate(self, tradingFeeRate)) {
            setMinAvailableFeeRate(self, tradingFeeRate);
        }
    }

    function burn(
        LpSlotSet storage self,
        LpContext memory ctx,
        int16 tradingFeeRate,
        uint256 liquidity,
        uint256 totalLiquidity
    ) internal _validTradingFeeRate(tradingFeeRate) returns (uint256 amount) {
        LpSlot storage slot = targetSlot(self, tradingFeeRate);

        amount = slot.burn(ctx, liquidity, totalLiquidity);
    }

    function targetSlots(
        LpSlotSet storage self,
        Position memory position
    ) private view returns (mapping(uint16 => LpSlot) storage) {
        return position.qty < 0 ? self._shortSlots : self._longSlots;
    }

    function targetSlot(
        LpSlotSet storage self,
        int16 tradingFeeRate
    ) private view returns (LpSlot storage) {
        return
            tradingFeeRate < 0
                ? self._shortSlots[abs(tradingFeeRate)]
                : self._longSlots[abs(tradingFeeRate)];
    }

    function minAvailableFeeRate(
        LpSlotSet storage self,
        Position memory position
    ) private view returns (uint16) {
        return minAvailableFeeRate(self, position.qty);
    }

    function minAvailableFeeRate(
        LpSlotSet storage self,
        int256 sign
    ) private view returns (uint16) {
        uint16 feeRate = sign < 0
            ? self._minAvailableFeeRateShort
            : self._minAvailableFeeRateLong;
        return feeRate == 0 ? MIN_FEE_RATE : feeRate;
    }

    function setMinAvailableFeeRate(
        LpSlotSet storage self,
        Position memory position,
        uint16 feeRate
    ) private {
        if (position.qty < 0) {
            self._minAvailableFeeRateShort = feeRate;
        } else {
            self._minAvailableFeeRateLong = feeRate;
        }
    }

    function setMinAvailableFeeRate(
        LpSlotSet storage self,
        int16 feeRate
    ) private {
        if (feeRate < 0) {
            self._minAvailableFeeRateShort = abs(feeRate);
        } else {
            self._minAvailableFeeRateLong = abs(feeRate);
        }
    }

    function divideToPositionParamValue(
        int256 leveragedQty,
        uint256 makerMargin,
        uint256 takerMargin,
        LpSlotMargin[] memory slotMargins
    ) private pure returns (_proportionalPositionParamValue[] memory) {
        uint256 remainLeveragedQty = leveragedQty.abs();
        uint256 remainTakerMargin = takerMargin;

        _proportionalPositionParamValue[]
            memory values = new _proportionalPositionParamValue[](
                slotMargins.length
            );

        for (uint256 i = 0; i < slotMargins.length - 1; i++) {
            uint256 _qty = remainLeveragedQty.mulDiv(
                slotMargins[i].amount,
                makerMargin
            );
            uint256 _takerMargin = remainTakerMargin.mulDiv(
                slotMargins[i].amount,
                makerMargin
            );

            values[i] = _proportionalPositionParamValue({
                leveragedQty: leveragedQty < 0
                    ? _qty.toInt256()
                    : -(_qty.toInt256()), // opposit side
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

    function newPositionParam(
        uint256 oracleVersion,
        uint256 timestamp
    ) private pure returns (PositionParam memory param) {
        param.oracleVersion = oracleVersion;
        param.timestamp = timestamp;
    }

    function validateTradingFeeRate(int16 tradingFeeRate) private pure {
        uint16[FEE_RATES_LENGTH] memory _tradingFeeRates = tradingFeeRates();

        uint16 absFeeRate = abs(tradingFeeRate);

        uint256 idx = findUpperBound(_tradingFeeRates, absFeeRate);
        if (
            idx >= _tradingFeeRates.length ||
            absFeeRate != _tradingFeeRates[idx]
        ) {
            revert UnsupportedTradingFeeRate();
        }
    }

    function abs(int16 i) private pure returns (uint16) {
        return i < 0 ? uint16(-i) : uint16(i);
    }

    function tradingFeeRates()
        private
        pure
        returns (uint16[FEE_RATES_LENGTH] memory)
    {
        // prettier-ignore
        return [
            MIN_FEE_RATE, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
            10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
            100, 200, 300, 400, 500, 600, 700, 700, 900, // 1% ~ 9%, step 1%
            1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
        ];
    }

    function findUpperBound(
        uint16[FEE_RATES_LENGTH] memory array,
        uint16 element
    ) internal pure returns (uint256) {
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
}
