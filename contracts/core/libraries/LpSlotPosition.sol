// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {AccruedInterest} from "@usum/core/libraries/AccruedInterest.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {PositionUtil, LEVERAGED_QTY_PRECISION} from "@usum/core/libraries/PositionUtil.sol";
import {LpSlotPendingPosition, LpSlotPendingPositionLib} from "@usum/core/libraries/LpSlotPendingPosition.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";

struct LpSlotPosition {
    int256 totalLeveragedQty;
    uint256 totalEntryAmount;
    uint256 _totalMakerMargin;
    uint256 _totalTakerMargin;
    LpSlotPendingPosition _pending;
    AccruedInterest _accruedInterest;
}

library LpSlotPositionLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;
    using LpSlotPendingPositionLib for LpSlotPendingPosition;

    modifier _settle(LpSlotPosition storage self, PositionParam memory param) {
        settleAccruedInterest(self, param.interestCalculator);
        settlePendingPosition(
            self,
            param.oracleProvider,
            param.settleOracleVersion(),
            param.currentOracleVersion()
        );

        _;
    }

    function settleAccruedInterest(
        LpSlotPosition storage self,
        IInterestCalculator calculator
    ) internal {
        self._accruedInterest.accumulate(
            calculator,
            self._totalMakerMargin,
            block.timestamp
        );
    }

    function settlePendingPosition(
        LpSlotPosition storage self,
        IOracleProvider provider,
        OracleVersion memory settleVersion,
        OracleVersion memory currentVersion
    ) internal {
        uint256 pendingOracleVersion = self._pending.oracleVersion;
        if (
            pendingOracleVersion == 0 ||
            pendingOracleVersion >= currentVersion.version
        ) return;

        int256 pendingQty = self._pending.totalLeveragedQty;
        self.totalLeveragedQty += pendingQty;
        self.totalEntryAmount +=
            pendingQty.abs() *
            self._pending.entryPrice(provider, settleVersion);
        self._totalMakerMargin += self._pending.totalMakerMargin;
        self._totalTakerMargin += self._pending.totalTakerMargin;
        self._accruedInterest.accumulatedAmount += self
            ._pending
            .accruedInterest
            .accumulatedAmount;

        delete self._pending;
    }

    function openPosition(
        LpSlotPosition storage self,
        PositionParam memory param
    ) internal _settle(self, param) {
        self._pending.openPosition(param);
    }

    function closePosition(
        LpSlotPosition storage self,
        PositionParam memory param
    ) internal _settle(self, param) {
        if (param.oracleVersion == self._pending.oracleVersion) {
            self._pending.closePosition(param);
        } else {
            int256 totalLeveragedQty = self.totalLeveragedQty;
            int256 leveragedQty = param.leveragedQty;
            PositionUtil.checkClosePositionQty(totalLeveragedQty, leveragedQty);

            self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
            self.totalEntryAmount -= leveragedQty.abs() * param.entryPrice();
            self._totalMakerMargin -= param.makerMargin;
            self._totalTakerMargin -= param.takerMargin;
            self._accruedInterest.deduct(
                param.calculateInterest(block.timestamp)
            );
        }
    }

    function totalMakerMargin(
        LpSlotPosition storage self
    ) internal view returns (uint256) {
        return self._totalMakerMargin + self._pending.totalMakerMargin;
    }

    function totalTakerMargin(
        LpSlotPosition storage self
    ) internal view returns (uint256) {
        return self._totalTakerMargin + self._pending.totalTakerMargin;
    }

    function unrealizedPnl(
        LpSlotPosition storage self,
        IOracleProvider provider,
        IInterestCalculator calculator,
        OracleVersion memory currentVersion,
        uint256 tokenPrecision
    ) internal view returns (int256) {
        int256 leveragedQty = self.totalLeveragedQty;
        int256 sign = leveragedQty < 0 ? int256(-1) : int256(1);
        uint256 exitPrice = PositionUtil.oraclePrice(currentVersion);

        int256 rawPnl = leveragedQty *
            exitPrice.toInt256() -
            self.totalEntryAmount.toInt256() *
            sign;
        int256 absRawPnl = rawPnl
            .abs()
            .mulDiv(
                tokenPrecision,
                LEVERAGED_QTY_PRECISION * provider.pricePrecision()
            )
            .toInt256();
        int256 pnl = (rawPnl < 0 ? -absRawPnl : absRawPnl) +
            self._pending.unrealizedPnl(
                provider,
                calculator,
                currentVersion,
                tokenPrecision
            ) +
            _currentInterest(self, calculator).toInt256();
        uint256 absPnl = pnl.abs();

        if (pnl >= 0) {
            return Math.min(absPnl, self._totalTakerMargin).toInt256();
        } else {
            return -(Math.min(absPnl, self._totalMakerMargin).toInt256());
        }
    }

    function currentInterest(
        LpSlotPosition storage self,
        IInterestCalculator calculator
    ) internal view returns (uint256) {
        return
            _currentInterest(self, calculator) +
            self._pending.currentInterest(calculator);
    }

    function _currentInterest(
        LpSlotPosition storage self,
        IInterestCalculator calculator
    ) private view returns (uint256) {
        return
            self._accruedInterest.calculateInterest(
                calculator,
                self._totalMakerMargin,
                block.timestamp
            );
    }
}
