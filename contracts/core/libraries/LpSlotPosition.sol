// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {AccruedInterest} from "@usum/core/libraries/AccruedInterest.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotPendingPosition, LpSlotPendingPositionLib} from "@usum/core/libraries/LpSlotPendingPosition.sol";
import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";

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

    modifier _settle(LpSlotPosition storage self, LpContext memory ctx) {
        settleAccruedInterest(self, ctx);
        settlePendingPosition(self, ctx);

        _;
    }

    function settleAccruedInterest(
        LpSlotPosition storage self,
        LpContext memory ctx
    ) internal {
        self._accruedInterest.accumulate(
            ctx.interestCalculator,
            self._totalMakerMargin,
            block.timestamp
        );
    }

    function settlePendingPosition(
        LpSlotPosition storage self,
        LpContext memory ctx
    ) internal {
        uint256 pendingOracleVersion = self._pending.oracleVersion;
        if (pendingOracleVersion == 0) return;

        OracleVersion memory currentVersion = ctx.currentOracleVersion();
        if (pendingOracleVersion >= currentVersion.version) return;

        int256 pendingQty = self._pending.totalLeveragedQty;
        self.totalLeveragedQty += pendingQty;
        self.totalEntryAmount += pendingQty.abs().mulDiv(
            self._pending.entryPrice(ctx),
            ctx.pricePrecision()
        );
        self._totalMakerMargin += self._pending.totalMakerMargin;
        self._totalTakerMargin += self._pending.totalTakerMargin;

        self._pending.settleAccruedInterest(ctx);
        self._accruedInterest.accumulatedAmount += self
            ._pending
            .accruedInterest
            .accumulatedAmount;

        delete self._pending;
    }

    function openPosition(
        LpSlotPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal _settle(self, ctx) {
        self._pending.openPosition(ctx, param);
    }

    function closePosition(
        LpSlotPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal _settle(self, ctx) {
        if (param.oracleVersion == self._pending.oracleVersion) {
            self._pending.closePosition(ctx, param);
        } else {
            int256 totalLeveragedQty = self.totalLeveragedQty;
            int256 leveragedQty = param.leveragedQty;
            PositionUtil.checkClosePositionQty(totalLeveragedQty, leveragedQty);

            self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
            self.totalEntryAmount -= leveragedQty.abs().mulDiv(
                param.entryPrice(ctx),
                ctx.pricePrecision()
            );
            self._totalMakerMargin -= param.makerMargin;
            self._totalTakerMargin -= param.takerMargin;
            self._accruedInterest.deduct(
                param.calculateInterest(ctx, block.timestamp)
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
        LpContext memory ctx
    ) internal view returns (int256) {
        OracleVersion memory currentVersion = ctx.currentOracleVersion();

        int256 leveragedQty = self.totalLeveragedQty;
        int256 sign = leveragedQty < 0 ? int256(-1) : int256(1);
        uint256 exitPrice = PositionUtil.oraclePrice(currentVersion);

        int256 entryAmount = self.totalEntryAmount.toInt256() * sign;
        int256 exitAmount = leveragedQty
            .abs()
            .mulDiv(exitPrice, ctx.pricePrecision())
            .toInt256() * sign;

        int256 rawPnl = exitAmount - entryAmount;
        int256 pnl = rawPnl +
            self._pending.unrealizedPnl(ctx) +
            _currentInterest(self, ctx).toInt256();
        uint256 absPnl = pnl.abs();

        if (pnl >= 0) {
            return Math.min(absPnl, self._totalTakerMargin).toInt256();
        } else {
            return -(Math.min(absPnl, self._totalMakerMargin).toInt256());
        }
    }

    function currentInterest(
        LpSlotPosition storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return _currentInterest(self, ctx) + self._pending.currentInterest(ctx);
    }

    function _currentInterest(
        LpSlotPosition storage self,
        LpContext memory ctx
    ) private view returns (uint256) {
        return
            self._accruedInterest.calculateInterest(
                ctx.interestCalculator,
                self._totalMakerMargin,
                block.timestamp
            );
    }
}
