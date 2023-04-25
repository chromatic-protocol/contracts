// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";

struct PositionParam {
    uint256 oracleVersion;
    int256 leveragedQty;
    uint256 takerMargin;
    uint256 makerMargin;
    uint256 timestamp;
    OracleVersion _settleVersionCache;
}

using PositionParamLib for PositionParam global;

library PositionParamLib {
    function settleVersion(
        PositionParam memory self
    ) internal pure returns (uint256) {
        return PositionUtil.settleVersion(self.oracleVersion);
    }

    function entryPrice(
        PositionParam memory self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return
            PositionUtil.entryPrice(
                ctx.oracleProvider,
                self.oracleVersion,
                self.settleOracleVersion(ctx)
            );
    }

    function settleOracleVersion(
        PositionParam memory self,
        LpContext memory ctx
    ) internal view returns (OracleVersion memory) {
        if (self._settleVersionCache.version == 0) {
            self._settleVersionCache = ctx.oracleVersionAt(
                self.settleVersion()
            );
        }

        return self._settleVersionCache;
    }

    // use only to deduct accumulated accrued interest when close position
    function calculateInterest(
        PositionParam memory self,
        LpContext memory ctx,
        uint256 until
    ) internal view returns (uint256) {
        return
            ctx.interestCalculator.calculateInterest(
                self.makerMargin,
                self.timestamp,
                until,
                Math.Rounding.Up
            );
    }

    function clone(
        PositionParam memory self
    ) internal pure returns (PositionParam memory) {
        return
            PositionParam({
                oracleVersion: self.oracleVersion,
                leveragedQty: self.leveragedQty,
                takerMargin: self.takerMargin,
                makerMargin: self.makerMargin,
                timestamp: self.timestamp,
                _settleVersionCache: self._settleVersionCache
            });
    }

    function inverse(
        PositionParam memory self
    ) internal pure returns (PositionParam memory) {
        PositionParam memory param = self.clone();
        param.leveragedQty *= -1;
        return param;
    }
}
