// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";

uint256 constant QTY_DECIMALS = 4;
uint256 constant LEVERAGE_DECIMALS = 2;
uint256 constant QTY_PRECISION = 10 ** QTY_DECIMALS;
uint256 constant LEVERAGE_PRECISION = 10 ** LEVERAGE_DECIMALS;
uint256 constant LEVERAGED_QTY_PRECISION = QTY_PRECISION * LEVERAGE_PRECISION;

library PositionUtil {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

    error InvalidOracleVersion();
    error UnsettledPosition();

    function settleVersion(
        uint256 oracleVersion
    ) internal pure returns (uint256) {
        if (oracleVersion == 0) revert InvalidOracleVersion();
        return oracleVersion + 1;
    }

    function entryPrice(
        IOracleProvider provider,
        uint256 oracleVersion
    ) internal view returns (uint256) {
        return entryPrice(provider, oracleVersion, provider.currentVersion());
    }

    function entryPrice(
        IOracleProvider provider,
        uint256 oracleVersion,
        OracleVersion memory currentVersion
    ) internal view returns (uint256) {
        uint256 _settleVersion = settleVersion(oracleVersion);
        if (_settleVersion > currentVersion.version) revert UnsettledPosition();

        OracleVersion memory _oracleVersion = _settleVersion ==
            currentVersion.version
            ? currentVersion
            : provider.atVersion(_settleVersion);
        return oraclePrice(_oracleVersion);
    }

    function oraclePrice(
        OracleVersion memory oracleVersion
    ) internal pure returns (uint256) {
        return oracleVersion.price < 0 ? 0 : uint256(oracleVersion.price);
    }

    function pnl(
        int256 leveragedQty,
        uint256 entryPrice,
        uint256 exitPrice,
        uint256 tokenPrecision
    ) internal pure returns (int256) {
        int256 delta = exitPrice > entryPrice
            ? (exitPrice - entryPrice).toInt256()
            : -(entryPrice - exitPrice).toInt256();
        if (leveragedQty < 0) delta *= -1;

        int256 absPnl = leveragedQty
            .abs()
            .mulDiv(tokenPrecision, LEVERAGED_QTY_PRECISION)
            .mulDiv(delta.abs(), entryPrice)
            .toInt256();

        return delta < 0 ? -absPnl : absPnl;
    }
}
