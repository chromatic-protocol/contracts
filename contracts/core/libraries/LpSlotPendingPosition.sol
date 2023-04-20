// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";

struct LpSlotPendingPosition {
    uint256 oracleVersion;
    int256 totalLeveragedQty;
}

library LpSlotPendingPositionLib {
    error InvalidOracleVersion();

    function openPosition(
        LpSlotPendingPosition storage self,
        PositionParam memory param,
        uint256 slotMargin
    ) internal {
        uint256 pendingVersion = self.oracleVersion;
        if (pendingVersion != 0 && pendingVersion != param.oracleVersion)
            revert InvalidOracleVersion();

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQtyByShare(slotMargin);
        PositionUtil.checkOpenPositionQty(totalLeveragedQty, leveragedQty);

        self.oracleVersion = param.oracleVersion;
        self.totalLeveragedQty = totalLeveragedQty + leveragedQty;
    }

    function closePosition(
        LpSlotPendingPosition storage self,
        PositionParam memory param,
        uint256 slotMargin
    ) internal {
        if (self.oracleVersion != param.oracleVersion)
            revert InvalidOracleVersion();

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQtyByShare(slotMargin);
        PositionUtil.checkClosePositionQty(totalLeveragedQty, leveragedQty);

        self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
    }

    function unrealizedPnl(
        LpSlotPendingPosition storage self,
        IOracleProvider provider,
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

        return
            PositionUtil.pnl(
                self.totalLeveragedQty,
                _entryPrice,
                _exitPrice,
                tokenPrecision
            );
    }

    function entryPrice(
        LpSlotPendingPosition memory self,
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
