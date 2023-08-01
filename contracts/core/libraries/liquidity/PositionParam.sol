// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {PositionUtil} from "@chromatic-protocol/contracts/core/libraries/PositionUtil.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";

/**
 * @dev A struct representing the parameters of a position.
 * @param openVersion The version of the position's open transaction
 * @param closeVersion The version of the position's close transaction
 * @param qty The quantity of the position
 * @param takerMargin The margin amount provided by the taker
 * @param makerMargin The margin amount provided by the maker
 * @param openTimestamp The timestamp of the position's open transaction
 * @param closeTimestamp The timestamp of the position's close transaction
 * @param _entryVersionCache Caches the settle oracle version for the position's entry
 * @param _exitVersionCache Caches the settle oracle version for the position's exit
 */
struct PositionParam {
    uint256 openVersion;
    uint256 closeVersion;
    int256 qty;
    uint256 takerMargin;
    uint256 makerMargin;
    uint256 openTimestamp;
    uint256 closeTimestamp;
    IOracleProvider.OracleVersion _entryVersionCache;
    IOracleProvider.OracleVersion _exitVersionCache;
}

using PositionParamLib for PositionParam global;

/**
 * @title PositionParamLib
 * @notice Library for manipulating PositionParam struct.
 */
library PositionParamLib {
    using Math for uint256;
    using SignedMath for int256;

    /**
     * @notice Returns the settle version for the position's entry.
     * @param self The PositionParam struct.
     * @return uint256 The settle version for the position's entry.
     */
    function entryVersion(PositionParam memory self) internal pure returns (uint256) {
        return PositionUtil.settleVersion(self.openVersion);
    }

    /**
     * @notice Calculates the entry price for a PositionParam.
     * @param self The PositionParam struct.
     * @param ctx The LpContext struct.
     * @return uint256 The entry price.
     */
    function entryPrice(
        PositionParam memory self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return
            PositionUtil.settlePrice(
                ctx.oracleProvider,
                self.openVersion,
                self.entryOracleVersion(ctx)
            );
    }

    /**
     * @notice Calculates the entry amount for a PositionParam.
     * @param self The PositionParam struct.
     * @param ctx The LpContext struct.
     * @return uint256 The entry amount.
     */
    function entryAmount(
        PositionParam memory self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return PositionUtil.transactionAmount(self.qty, self.entryPrice(ctx));
    }

    /**
     * @notice Retrieves the settle oracle version for the position's entry.
     * @param self The PositionParam struct.
     * @param ctx The LpContext struct.
     * @return OracleVersion The settle oracle version for the position's entry.
     */
    function entryOracleVersion(
        PositionParam memory self,
        LpContext memory ctx
    ) internal view returns (IOracleProvider.OracleVersion memory) {
        if (self._entryVersionCache.version == 0) {
            self._entryVersionCache = ctx.oracleVersionAt(self.entryVersion());
        }
        return self._entryVersionCache;
    }

    /**
     * @dev Calculates the interest for a PositionParam until a specified timestamp.
     * @dev It is used only to deduct accumulated accrued interest when close position
     * @param self The PositionParam struct.
     * @param ctx The LpContext struct.
     * @param until The timestamp until which to calculate the interest.
     * @return uint256 The calculated interest.
     */
    function calculateInterest(
        PositionParam memory self,
        LpContext memory ctx,
        uint256 until
    ) internal view returns (uint256) {
        return ctx.calculateInterest(self.makerMargin, self.openTimestamp, until);
    }

    /**
     * @notice Creates a clone of a PositionParam.
     * @param self The PositionParam data struct.
     * @return PositionParam The cloned PositionParam.
     */
    function clone(PositionParam memory self) internal pure returns (PositionParam memory) {
        return
            PositionParam({
                openVersion: self.openVersion,
                closeVersion: self.closeVersion,
                qty: self.qty,
                takerMargin: self.takerMargin,
                makerMargin: self.makerMargin,
                openTimestamp: self.openTimestamp,
                closeTimestamp: self.closeTimestamp,
                _entryVersionCache: self._entryVersionCache,
                _exitVersionCache: self._exitVersionCache
            });
    }

    /**
     * @notice Creates the inverse of a PositionParam by negating the qty.
     * @param self The PositionParam data struct.
     * @return PositionParam The inverted PositionParam.
     */
    function inverse(PositionParam memory self) internal pure returns (PositionParam memory) {
        PositionParam memory param = self.clone();
        param.qty *= -1;
        return param;
    }
}
