// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";

struct PositionParam {
    IOracleProvider oracleProvider;
    IInterestCalculator interestCalculator;
    uint256 oracleVersion;
    int256 leveragedQty;
    uint256 takerMargin;
    uint256 makerMargin;
    uint256 timestamp;
    OracleVersion _settleVersionCache;
    OracleVersion _currentVersionCache;
}

using PositionParamLib for PositionParam global;

library PositionParamLib {
    function settleVersion(
        PositionParam memory self
    ) internal pure returns (uint256) {
        return PositionUtil.settleVersion(self.oracleVersion);
    }

    function entryPrice(
        PositionParam memory self
    ) internal view returns (uint256) {
        return self.entryPrice(self.settleOracleVersion());
    }

    function entryPrice(
        PositionParam memory self,
        OracleVersion memory currentVersion
    ) internal view returns (uint256) {
        return
            PositionUtil.entryPrice(
                self.oracleProvider,
                self.oracleVersion,
                currentVersion
            );
    }

    function clone(
        PositionParam memory self
    ) internal pure returns (PositionParam memory) {
        return
            PositionParam({
                oracleProvider: self.oracleProvider,
                interestCalculator: self.interestCalculator,
                oracleVersion: self.oracleVersion,
                leveragedQty: self.leveragedQty,
                takerMargin: self.takerMargin,
                makerMargin: self.makerMargin,
                timestamp: self.timestamp,
                _settleVersionCache: self._settleVersionCache,
                _currentVersionCache: self._currentVersionCache
            });
    }

    function settleOracleVersion(
        PositionParam memory self
    ) internal view returns (OracleVersion memory) {
        if (self._settleVersionCache.version == 0) {
            self._settleVersionCache = self.oracleVersionAt(
                self.settleVersion()
            );
        }

        return self._settleVersionCache;
    }

    function currentOracleVersion(
        PositionParam memory self
    ) internal view returns (OracleVersion memory) {
        if (self._currentVersionCache.version == 0) {
            self._currentVersionCache = self.oracleProvider.currentVersion();
        }

        return self._currentVersionCache;
    }

    function oracleVersionAt(
        PositionParam memory self,
        uint256 version
    ) internal view returns (OracleVersion memory) {
        return self.oracleProvider.atVersion(version);
    }

    // use only to deduct accumulated accrued interest when close position
    function calculateInterest(
        PositionParam memory self,
        uint256 until
    ) internal view returns (uint256) {
        return
            self.interestCalculator.calculateInterest(
                self.makerMargin,
                self.timestamp,
                until,
                Math.Rounding.Up
            );
    }
}
