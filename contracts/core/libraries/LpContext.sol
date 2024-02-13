// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@chromatic-protocol/contracts/core/interfaces/IInterestCalculator.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";

/**
 * @dev Represents the context information required for LP bin operations.
 * @param oracleProvider The Oracle Provider contract used for price feed
 * @param interestCalculator The Interest Calculator contract used for interest calculations
 * @param vault The Chromatic Vault contract responsible for managing liquidity and margin
 * @param clbToken The CLB token contract that represents LP ownership in the pool
 * @param market The address of market contract
 * @param settlementToken The address of the settlement token used in the market
 * @param tokenPrecision The precision of the settlement token used in the market
 * @param _currentVersionCache Cached instance of the current oracle version
 */
struct LpContext {
    IOracleProvider oracleProvider;
    IInterestCalculator interestCalculator;
    IChromaticVault vault;
    ICLBToken clbToken;
    address market;
    address settlementToken;
    uint256 tokenPrecision;
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
     */
    function syncOracleVersion(LpContext memory self) internal {
        self._currentVersionCache = self.oracleProvider.sync();
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
            //slither-disable-next-line calls-loop
            self._currentVersionCache = self.oracleProvider.currentVersion();
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
        return self.oracleProvider.atVersion(version);
    }

    /**
     * @notice Calculates the interest accrued for a given amount of settlement tokens
               within a specified time range.
     * @dev This function internally calls the `calculateInterest` function on the `interestCalculator` contract.
     * @param self The memory instance of the `LpContext` struct.
     * @param amount The amount of settlement tokens for which the interest needs to be calculated.
     * @param from The starting timestamp of the time range (inclusive).
     * @param to The ending timestamp of the time range (exclusive).
     * @return The accrued interest as a `uint256` value.
     */
    function calculateInterest(
        LpContext memory self,
        uint256 amount,
        uint256 from,
        uint256 to
    ) internal view returns (uint256) {
        //slither-disable-next-line calls-loop
        return
            amount == 0 || from >= to
                ? 0
                : self.interestCalculator.calculateInterest(self.settlementToken, amount, from, to);
    }

    /**
     * @notice Checks if an oracle version is in the past.
     * @param self The memory instance of the `LpContext` struct.
     * @param oracleVersion The oracle version to check.
     * @return A boolean value indicating whether the oracle version is in the past.
     */
    function isPastVersion(
        LpContext memory self,
        uint256 oracleVersion
    ) internal view returns (bool) {
        return oracleVersion != 0 && oracleVersion < self.currentOracleVersion().version;
    }
}
