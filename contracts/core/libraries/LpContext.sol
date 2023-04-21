// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";

struct LpContext {
    IOracleProvider oracleProvider;
    IInterestCalculator interestCalculator;
    uint256 tokenPrecision;
    uint256 _pricePrecision;
    OracleVersion _currentVersionCache;
}

using LpContextLib for LpContext global;

library LpContextLib {
    function currentOracleVersion(
        LpContext memory self
    ) internal view returns (OracleVersion memory) {
        if (self._currentVersionCache.version == 0) {
            self._currentVersionCache = self.oracleProvider.currentVersion();
        }

        return self._currentVersionCache;
    }

    function oracleVersionAt(
        LpContext memory self,
        uint256 version
    ) internal view returns (OracleVersion memory) {
        return self.oracleProvider.atVersion(version);
    }

    function pricePrecision(
        LpContext memory self
    ) internal view returns (uint256) {
        if (self._pricePrecision == 0) {
            self._pricePrecision = self.oracleProvider.pricePrecision();
        }
        return self._pricePrecision;
    }
}
