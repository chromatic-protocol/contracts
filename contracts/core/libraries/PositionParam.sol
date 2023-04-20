// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";

struct PositionParam {
    IOracleProvider oracleProvider;
    IInterestCalculator interestCalculator;
    uint256 oracleVersion;
    int256 qty;
    uint256 leverage;
    uint256 takerMargin;
    uint256 makerMargin;
    uint256 timestamp;
    OracleVersion _settleVersionCache;
    OracleVersion _currentVersionCache;
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

    function inverse(
        PositionParam memory self
    ) internal pure returns (PositionParam memory) {
        return
            PositionParam({
                oracleProvider: self.oracleProvider,
                interestCalculator: self.interestCalculator,
                oracleVersion: self.oracleVersion,
                qty: -(self.qty),
                leverage: self.leverage,
                takerMargin: self.takerMargin,
                makerMargin: self.makerMargin,
                timestamp: self.timestamp,
                _settleVersionCache: self._settleVersionCache,
                _currentVersionCache: self._currentVersionCache
            });
    }

    function leveragedQty(
        PositionParam memory self
    ) internal pure returns (int256) {
        return self.qty * self.leverage.toInt256();
    }

    function leveragedQtyByShare(
        PositionParam memory self,
        uint256 slotMargin
    ) internal pure returns (int256) {
        int256 _byShare = self
            .leveragedQty()
            .abs()
            .mulDiv(slotMargin, self.makerMargin)
            .toInt256();
        return self.qty < 0 ? -(_byShare) : _byShare;
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

    function currentPnl(
        PositionParam memory self,
        uint256 tokenPrecision
    ) internal view returns (int256) {
        return self.pnl(self.currentOracleVersion(), tokenPrecision);
    }

    function pnl(
        PositionParam memory self,
        OracleVersion memory currentVersion,
        uint256 tokenPrecision
    ) internal view returns (int256) {
        uint256 _entryPrice = self.entryPrice();
        uint256 _exitPrice = PositionUtil.oraclePrice(currentVersion);
        return
            PositionUtil.pnl(
                self.qty * self.leverage.toInt256(),
                _entryPrice,
                _exitPrice,
                tokenPrecision
            );
    }
}
