// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {AccruedInterest} from "@usum/core/libraries/AccruedInterest.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";

struct LpSlotPendingPosition {
    uint256 oracleVersion;
    int256 totalLeveragedQty;
    uint256 totalMakerMargin;
    uint256 totalTakerMargin;
    AccruedInterest accruedInterest;
}

library LpSlotPendingPositionLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

    error InvalidOracleVersion();

    modifier _settle(LpSlotPendingPosition storage self, LpContext memory ctx) {
        settleAccruedInterest(self, ctx);

        _;
    }

    function settleAccruedInterest(
        LpSlotPendingPosition storage self,
        LpContext memory ctx
    ) internal {
        self.accruedInterest.accumulate(
            ctx.interestCalculator,
            self.totalMakerMargin,
            block.timestamp
        );
    }

    function openPosition(
        LpSlotPendingPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal _settle(self, ctx) {
        uint256 pendingVersion = self.oracleVersion;
        if (pendingVersion != 0 && pendingVersion != param.oracleVersion)
            revert InvalidOracleVersion();

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty(ctx);
        PositionUtil.checkOpenPositionQty(totalLeveragedQty, leveragedQty);

        self.oracleVersion = param.oracleVersion;
        self.totalLeveragedQty = totalLeveragedQty + leveragedQty;
        self.totalMakerMargin += param.makerMargin;
        self.totalTakerMargin += param.takerMargin;
    }

    function closePosition(
        LpSlotPendingPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal _settle(self, ctx) {
        if (self.oracleVersion != param.oracleVersion)
            revert InvalidOracleVersion();

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty(ctx);
        PositionUtil.checkClosePositionQty(totalLeveragedQty, leveragedQty);

        self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
        self.totalMakerMargin -= param.makerMargin;
        self.totalTakerMargin -= param.takerMargin;
        self.accruedInterest.deduct(
            param.calculateInterest(ctx, block.timestamp)
        );
    }

    function unrealizedPnl(
        LpSlotPendingPosition storage self,
        LpContext memory ctx
    ) internal view returns (int256) {
        if (self.oracleVersion == 0) return 0;

        OracleVersion memory currentVersion = ctx.currentOracleVersion();
        if (self.oracleVersion >= currentVersion.version) return 0;

        uint256 _entryPrice = PositionUtil.entryPrice(
            ctx.oracleProvider,
            self.oracleVersion,
            currentVersion
        );
        uint256 _exitPrice = PositionUtil.oraclePrice(currentVersion);

        int256 pnl = PositionUtil.pnl(
            self.totalLeveragedQty,
            _entryPrice,
            _exitPrice
        ) + currentInterest(self, ctx).toInt256();
        uint256 absPnl = pnl.abs();

        if (pnl >= 0) {
            return Math.min(absPnl, self.totalTakerMargin).toInt256();
        } else {
            return -(Math.min(absPnl, self.totalMakerMargin).toInt256());
        }
    }

    function currentInterest(
        LpSlotPendingPosition storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return
            self.accruedInterest.calculateInterest(
                ctx.interestCalculator,
                self.totalMakerMargin,
                block.timestamp
            );
    }

    function entryPrice(
        LpSlotPendingPosition storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return
            PositionUtil.entryPrice(
                ctx.oracleProvider,
                self.oracleVersion,
                ctx.currentOracleVersion()
            );
    }
}
