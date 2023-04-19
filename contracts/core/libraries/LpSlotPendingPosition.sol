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
    function openPosition(
        LpSlotPendingPosition storage self,
        PositionParam memory param,
        uint256 slotMargin
    ) internal {
        self.oracleVersion = param.currentOracleVersion().version;
        self.totalLeveragedQty += param.leveragedQtyByShare(slotMargin);
    }

    function closePosition(
        LpSlotPendingPosition storage self,
        PositionParam memory param,
        uint256 slotMargin
    ) internal {
        if (self.oracleVersion >= param.currentOracleVersion().version) {
            self.totalLeveragedQty -= param.leveragedQtyByShare(slotMargin);
        }
    }

    function unrealizedPnl(
        LpSlotPendingPosition storage self,
        IOracleProvider provider,
        uint256 tokenPrecision
    ) internal view returns (int256) {
        if (self.oracleVersion == 0) return 0;

        OracleVersion memory currentVersion = provider.currentVersion();
        if (self.oracleVersion >= currentVersion.version) return 0;

        uint256 entryPrice = PositionUtil.entryPrice(
            provider,
            self.oracleVersion,
            currentVersion
        );
        uint256 exitPrice = PositionUtil.oraclePrice(currentVersion);

        return
            PositionUtil.pnl(
                self.totalLeveragedQty,
                entryPrice,
                exitPrice,
                tokenPrecision
            );
    }
}
