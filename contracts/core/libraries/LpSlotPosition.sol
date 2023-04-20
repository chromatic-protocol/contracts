// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {PositionUtil, LEVERAGED_QTY_PRECISION} from "@usum/core/libraries/PositionUtil.sol";
import {LpSlotPendingPosition, LpSlotPendingPositionLib} from "@usum/core/libraries/LpSlotPendingPosition.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";

struct LpSlotPosition {
    int256 totalLeveragedQty;
    uint256 totalEntryAmount;
    LpSlotPendingPosition _pending;
}

library LpSlotPositionLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;
    using LpSlotPendingPositionLib for LpSlotPendingPosition;

    modifier _settle(LpSlotPosition storage self, PositionParam memory param) {
        settlePendingPosition(
            self,
            param.oracleProvider,
            param.settleOracleVersion(),
            param.currentOracleVersion()
        );

        _;
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

        delete self._pending;
    }

    function openPosition(
        LpSlotPosition storage self,
        PositionParam memory param,
        uint256 slotMargin
    ) internal _settle(self, param) {
        self._pending.openPosition(param, slotMargin);
    }

    function closePosition(
        LpSlotPosition storage self,
        PositionParam memory param,
        uint256 slotMargin
    ) internal _settle(self, param) {
        if (param.oracleVersion == self._pending.oracleVersion) {
            self._pending.closePosition(param, slotMargin);
        } else {
            int256 totalLeveragedQty = self.totalLeveragedQty;
            int256 leveragedQty = param.leveragedQtyByShare(slotMargin);
            PositionUtil.checkClosePositionQty(totalLeveragedQty, leveragedQty);

            self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
            self.totalEntryAmount -= leveragedQty.abs() * param.entryPrice();
        }
    }

    function unrealizedPnl(
        LpSlotPosition storage self,
        IOracleProvider provider,
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
        int256 absPnl = rawPnl
            .abs()
            .mulDiv(
                tokenPrecision,
                LEVERAGED_QTY_PRECISION * provider.pricePrecision()
            )
            .toInt256();
        return
            (rawPnl < 0 ? -(absPnl) : absPnl) +
            self._pending.unrealizedPnl(
                provider,
                currentVersion,
                tokenPrecision
            );
    }
}
