// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {UFixed18} from "@equilibria/root/number/types/UFixed18.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";

struct PositionParam {
    uint256 oracleVersion;
    int256 leveragedQty;
    uint256 takerMargin;
    uint256 makerMargin;
    uint256 timestamp;
    IOracleProvider.OracleVersion _settleVersionCache;
}

using PositionParamLib for PositionParam global;

/**
 * @title PositionParamLib
 * @notice Library for manipulating PositionParam struct.
 */
library PositionParamLib {
    /**
     * @notice Returns the settle version for a PositionParam.
     * @param self The PositionParam data struct.
     * @return uint256 The settle version.
     */
    function settleVersion(
        PositionParam memory self
    ) internal pure returns (uint256) {
        return PositionUtil.settleVersion(self.oracleVersion);
    }

    /**
     * @notice Calculates the entry price for a PositionParam.
     * @param self The PositionParam data struct.
     * @param ctx The LpContext data struct.
     * @return UFixed18 The entry price.
     */
    function entryPrice(
        PositionParam memory self,
        LpContext memory ctx
    ) internal view returns (UFixed18) {
        return
            PositionUtil.settlePrice(
                ctx.market.oracleProvider(),
                self.oracleVersion,
                self.settleOracleVersion(ctx)
            );
    }

    /**
     * @notice Retrieves the settle oracle version for a PositionParam.
     * @param self The PositionParam data struct.
     * @param ctx The LpContext data struct.
     * @return OracleVersion The settle oracle version.
     */
    function settleOracleVersion(
        PositionParam memory self,
        LpContext memory ctx
    ) internal view returns (IOracleProvider.OracleVersion memory) {
        if (self._settleVersionCache.version == 0) {
            self._settleVersionCache = ctx.oracleVersionAt(
                self.settleVersion()
            );
        }

        return self._settleVersionCache;
    }

    /**
     * @dev Calculates the interest for a PositionParam until a specified timestamp.
     * @dev It is used only to deduct accumulated accrued interest when close position
     * @param self The PositionParam data struct.
     * @param ctx The LpContext data struct.
     * @param until The timestamp until which to calculate the interest.
     * @return uint256 The calculated interest.
     */
    function calculateInterest(
        PositionParam memory self,
        LpContext memory ctx,
        uint256 until
    ) internal view returns (uint256) {
        return
            ctx.market.calculateInterest(
                self.makerMargin,
                self.timestamp,
                until
            );
    }

    /**
     * @notice Creates a clone of a PositionParam.
     * @param self The PositionParam data struct.
     * @return PositionParam The cloned PositionParam.
     */
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

    /**
     * @notice Creates the inverse of a PositionParam by negating the leveragedQty.
     * @param self The PositionParam data struct.
     * @return PositionParam The inverted PositionParam.
     */
    function inverse(
        PositionParam memory self
    ) internal pure returns (PositionParam memory) {
        PositionParam memory param = self.clone();
        param.leveragedQty *= -1;
        return param;
    }
}
