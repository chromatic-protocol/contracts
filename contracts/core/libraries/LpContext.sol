// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";

struct LpContext {
    IUSUMMarket market;
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
            self._currentVersionCache = self
                .market
                .oracleProvider()
                .currentVersion();
        }

        return self._currentVersionCache;
    }

    function oracleVersionAt(
        LpContext memory self,
        uint256 version
    ) internal view returns (OracleVersion memory) {
        if (self._currentVersionCache.version == version) {
            return self._currentVersionCache;
        }
        return self.market.oracleProvider().atVersion(version);
    }

    function pricePrecision(
        LpContext memory self
    ) internal view returns (uint256) {
        if (self._pricePrecision == 0) {
            self._pricePrecision = self
                .market
                .oracleProvider()
                .pricePrecision();
        }
        return self._pricePrecision;
    }
}
