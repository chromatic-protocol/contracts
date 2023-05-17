// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {Errors} from "@usum/core/libraries/Errors.sol";

uint256 constant QTY_DECIMALS = 4;
uint256 constant LEVERAGE_DECIMALS = 2;
uint256 constant QTY_PRECISION = 10 ** QTY_DECIMALS;
uint256 constant LEVERAGE_PRECISION = 10 ** LEVERAGE_DECIMALS;
uint256 constant QTY_LEVERAGE_PRECISION = QTY_PRECISION * LEVERAGE_PRECISION;

/**
 * @title PositionUtil
 * @notice Provides utility functions for managing positions
 */
library PositionUtil {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

    /**
     * @notice Returns next oracle version to settle
     * @dev It adds 1 to the `oracleVersion`
     *      and ensures that the `oracleVersion` is greater than 0 using a require statement.
     *      If the `oracleVersion` is not valid,
     *      it will trigger an error with the message `INVALID_ORACLE_VERSION`.
     * @param oracleVersion Input oracle version
     * @return uint256 Next oracle version to settle
     */
    function settleVersion(
        uint256 oracleVersion
    ) internal pure returns (uint256) {
        require(oracleVersion > 0, Errors.INVALID_ORACLE_VERSION);
        return oracleVersion + 1;
    }

    /**
     * @notice Calculates the entry price of the position based on the `oracleVersion`
     * @dev It calls another overloaded `entryPrice` function
     *      with an additional `OracleVersion` parameter,
     *      passing the `currentVersion` obtained from the `provider`
     * @param provider The oracle provider
     * @param oracleVersion The oracle version of position
     * @return uint256 The calculated entry price
     */
    function entryPrice(
        IOracleProvider provider,
        uint256 oracleVersion
    ) internal view returns (uint256) {
        return entryPrice(provider, oracleVersion, provider.currentVersion());
    }

    /**
     * @notice Calculates the entry price of the position based on the `oracleVersion`
     * @dev It calculates the entry price by considering the `settleVersion`
     *      and the `currentVersion` obtained from the `IOracleProvider`.
     *      It ensures that the settle version is not greater than the current version;
     *      otherwise, it triggers an error with the message `UNSETTLED_POSITION`.
     *      It retrieves the corresponding `OracleVersion` using `atVersion` from the `IOracleProvider`,
     *      and then calls `oraclePrice` to obtain the entry price.
     * @param provider The oracle provider
     * @param oracleVersion The oracle version of position
     * @param currentVersion The current oracle version
     * @return uint256 The calculated entry price
     */
    function entryPrice(
        IOracleProvider provider,
        uint256 oracleVersion,
        OracleVersion memory currentVersion
    ) internal view returns (uint256) {
        uint256 _settleVersion = settleVersion(oracleVersion);
        require(
            _settleVersion <= currentVersion.version,
            Errors.UNSETTLED_POSITION
        );

        OracleVersion memory _oracleVersion = _settleVersion ==
            currentVersion.version
            ? currentVersion
            : provider.atVersion(_settleVersion);
        return oraclePrice(_oracleVersion);
    }

    /**
     * @notice Extracts the price value from an `OracleVersion` struct
     * @dev If the price is less than 0, it returns 0
     * @param oracleVersion The memory instance of `OracleVersion` struct
     * @return uint256 The price value of `oracleVersion`
     */
    function oraclePrice(
        OracleVersion memory oracleVersion
    ) internal pure returns (uint256) {
        return oracleVersion.price < 0 ? 0 : uint256(oracleVersion.price);
    }

    /**
     * @notice Calculates the profit or loss (PnL) for a position
     *         based on the leveraged quantity, entry price, and exit price
     * @dev It first calculates the price difference (`delta`) between the exit price and the entry price.
     *      If the leveraged quantity is negative, indicating short position,
     *      it adjusts the `delta` to reflect a negative change.
     *      The function then calculates the absolute PnL
     *      by multiplying the absolute value of the leveraged quantity
     *      with the absolute value of the `delta`, divided by the entry price.
     *      Finally, if `delta` is negative, indicating a loss,
     *      the absolute PnL is negated to represent a negative value.
     * @param leveragedQty The leveraged quantity of the position
     * @param _entryPrice The entry price of the position
     * @param _exitPrice The exit price of the position
     * @return int256 The profit or loss
     */
    function pnl(
        int256 leveragedQty, // as token precision
        uint256 _entryPrice,
        uint256 _exitPrice
    ) internal pure returns (int256) {
        int256 delta = _exitPrice > _entryPrice
            ? (_exitPrice - _entryPrice).toInt256()
            : -(_entryPrice - _exitPrice).toInt256();
        if (leveragedQty < 0) delta *= -1;

        int256 absPnl = leveragedQty
            .abs()
            .mulDiv(delta.abs(), _entryPrice)
            .toInt256();

        return delta < 0 ? -absPnl : absPnl;
    }

    /**
     * @notice Verifies the validity of an open position quantity
     * @dev It ensures that the sign of the current quantity of the slot's pending position
     *      and the open quantity are same or zero.
     *      If the condition is not met, it triggers an error with the message `INVALID_POSITION_QTY`.
     * @param currentQty The current quantity of the slot's pending position
     * @param openQty The open position quantity
     */
    function checkOpenPositionQty(
        int256 currentQty,
        int256 openQty
    ) internal pure {
        require(
            !((currentQty > 0 && openQty <= 0) ||
                (currentQty < 0 && openQty >= 0)),
            Errors.INVALID_POSITION_QTY
        );
    }

    /**
     * @notice Verifies the validity of an close position quantity
     * @dev It ensures that the sign of the current quantity of the slot's position is not zero,
     *      the close quantity is not zero,
     *      and the absolute close quantity is not greater than the absolute current quantity.
     *      If the condition is not met, it triggers an error with the message `INVALID_POSITION_QTY`.
     * @param currentQty The current quantity of the slot's position
     * @param closeQty The close position quantity
     */
    function checkClosePositionQty(
        int256 currentQty,
        int256 closeQty
    ) internal pure {
        require(
            !((currentQty == 0) ||
                (closeQty == 0) ||
                (currentQty > 0 && closeQty > currentQty) ||
                (currentQty < 0 && closeQty < currentQty)),
            Errors.INVALID_POSITION_QTY
        );
    }
}
