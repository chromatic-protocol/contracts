// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {AccruedInterest} from "@usum/core/libraries/AccruedInterest.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";

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

    modifier _settle(
        LpSlotPendingPosition storage self,
        PositionParam memory param
    ) {
        settleAccruedInterest(self, param.interestCalculator);

        _;
    }

    function settleAccruedInterest(
        LpSlotPendingPosition storage self,
        IInterestCalculator calculator
    ) internal {
        self.accruedInterest.accumulate(
            calculator,
            self.totalMakerMargin,
            block.timestamp
        );
    }

    function openPosition(
        LpSlotPendingPosition storage self,
        PositionParam memory param
    ) internal _settle(self, param) {
        uint256 pendingVersion = self.oracleVersion;
        if (pendingVersion != 0 && pendingVersion != param.oracleVersion)
            revert InvalidOracleVersion();

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty;
        PositionUtil.checkOpenPositionQty(totalLeveragedQty, leveragedQty);

        self.oracleVersion = param.oracleVersion;
        self.totalLeveragedQty = totalLeveragedQty + leveragedQty;
        self.totalMakerMargin += param.makerMargin;
        self.totalTakerMargin += param.takerMargin;
    }

    function closePosition(
        LpSlotPendingPosition storage self,
        PositionParam memory param
    ) internal _settle(self, param) {
        if (self.oracleVersion != param.oracleVersion)
            revert InvalidOracleVersion();

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty;
        PositionUtil.checkClosePositionQty(totalLeveragedQty, leveragedQty);

        self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
        self.totalMakerMargin -= param.makerMargin;
        self.totalTakerMargin -= param.takerMargin;
        self.accruedInterest.deduct(param.calculateInterest(block.timestamp));
    }

    function unrealizedPnl(
        LpSlotPendingPosition storage self,
        IOracleProvider provider,
        IInterestCalculator calculator,
        OracleVersion memory currentVersion,
        uint256 tokenPrecision
    ) internal view returns (int256) {
        if (
            self.oracleVersion == 0 ||
            self.oracleVersion >= currentVersion.version
        ) return 0;

        uint256 _entryPrice = PositionUtil.entryPrice(
            provider,
            self.oracleVersion,
            currentVersion
        );
        uint256 _exitPrice = PositionUtil.oraclePrice(currentVersion);

        int256 pnl = PositionUtil.pnl(
            self.totalLeveragedQty,
            _entryPrice,
            _exitPrice,
            tokenPrecision
        ) + currentInterest(self, calculator).toInt256();
        uint256 absPnl = pnl.abs();

        if (pnl >= 0) {
            return Math.min(absPnl, self.totalTakerMargin).toInt256();
        } else {
            return -(Math.min(absPnl, self.totalMakerMargin).toInt256());
        }
    }

    function currentInterest(
        LpSlotPendingPosition storage self,
        IInterestCalculator calculator
    ) internal view returns (uint256) {
        return
            self.accruedInterest.calculateInterest(
                calculator,
                self.totalMakerMargin,
                block.timestamp
            );
    }

    function entryPrice(
        LpSlotPendingPosition storage self,
        IOracleProvider provider,
        OracleVersion memory currentVersion
    ) internal view returns (uint256) {
        return
            PositionUtil.entryPrice(
                provider,
                self.oracleVersion,
                currentVersion
            );
    }
}
