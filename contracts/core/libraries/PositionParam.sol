// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {PositionUtil, QTY_LEVERAGE_PRECISION} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";

struct PositionParam {
    uint256 oracleVersion;
    int256 qty;
    uint256 leverage;
    uint256 takerMargin;
    uint256 makerMargin;
    uint256 timestamp;
    OracleVersion _settleVersionCache;
}

using PositionParamLib for PositionParam global;

library PositionParamLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

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

    function leveragedQty(
        PositionParam memory self,
        LpContext memory ctx
    ) internal pure returns (int256) {
        int256 qty = self.qty;
        int256 leveraged = qty
            .abs()
            .mulDiv(self.leverage * ctx.tokenPrecision, QTY_LEVERAGE_PRECISION)
            .toInt256();
        return qty < 0 ? -leveraged : leveraged;
    }

    function clone(
        PositionParam memory self
    ) internal pure returns (PositionParam memory) {
        return
            PositionParam({
                oracleVersion: self.oracleVersion,
                qty: self.qty,
                leverage: self.leverage,
                takerMargin: self.takerMargin,
                makerMargin: self.makerMargin,
                timestamp: self.timestamp,
                _settleVersionCache: self._settleVersionCache
            });
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
}
