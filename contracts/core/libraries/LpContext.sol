// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IUSUMVault} from "@usum/core/interfaces/IUSUMVault.sol";
import {IUSUMLpToken} from "@usum/core/interfaces/IUSUMLpToken.sol";

/// @dev LpContext type
struct LpContext {
    IOracleProvider oracleProvider;
    IUSUMVault vault;
    IUSUMLpToken lpToken;
    /// @dev The address of market contract
    IUSUMMarket market;
    /// @dev The precision of the settlement token used in the market
    uint256 tokenPrecision;
    /// @dev Cached instance of `OracleVersion` struct, which represents the current oracle version
    IOracleProvider.OracleVersion _currentVersionCache;
}

using LpContextLib for LpContext global;

/**
 * @title LpContextLib
 * @notice Provides functions that operate on the `LpContext` struct
 */
library LpContextLib {
    /**
     * @notice Syncs the oracle version used by the market.
     * @param self The memory instance of `LpContext` struct
     * @return OracleVersion The current oracle version.
     */
    function syncOracleVersion(
        LpContext memory self
    ) internal returns (IOracleProvider.OracleVersion memory) {
        self._currentVersionCache = self.market.oracleProvider().sync();
        return self._currentVersionCache;
    }

    /**
     * @notice Retrieves the current oracle version used by the market
     * @dev If the `_currentVersionCache` has been initialized, then returns it.
     *      If not, it calls the `currentVersion` function on the `oracleProvider of the market
     *      to fetch the current version and stores it in the cache,
     *      and then returns the current version.
     * @param self The memory instance of `LpContext` struct
     * @return OracleVersion The current oracle version
     */
    function currentOracleVersion(
        LpContext memory self
    ) internal view returns (IOracleProvider.OracleVersion memory) {
        if (self._currentVersionCache.version == 0) {
            self._currentVersionCache = self.market.oracleProvider().currentVersion();
        }

        return self._currentVersionCache;
    }

    /**
     * @notice Retrieves the oracle version at a specific version number
     * @dev If the `_currentVersionCache` matches the requested version, then returns it.
     *      Otherwise, it calls the `atVersion` function on the `oracleProvider` of the market
     *      to fetch the desired version.
     * @param self The memory instance of `LpContext` struct
     * @param version The requested version number
     * @return OracleVersion The oracle version at the requested version number
     */
    function oracleVersionAt(
        LpContext memory self,
        uint256 version
    ) internal view returns (IOracleProvider.OracleVersion memory) {
        if (self._currentVersionCache.version == version) {
            return self._currentVersionCache;
        }
        return self.market.oracleProvider().atVersion(version);
    }
}
