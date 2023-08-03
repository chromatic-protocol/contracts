// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";

/**
 * @title IChromaticTradeCallback
 * @dev The interface for handling callbacks related to Chromatic trading operations.
 */
interface IChromaticTradeCallback {
    /**
     * @notice Callback function called after opening a position.
     * @param settlementToken The address of the settlement token used in the position.
     * @param vault The address of the vault contract.
     * @param marginRequired The amount of margin required for the position.
     * @param data Additional data related to the callback.
     */
    function openPositionCallback(
        address settlementToken,
        address vault,
        uint256 marginRequired,
        bytes calldata data
    ) external;

    /**
     * @notice Callback function called after claiming a position.
     * @param position The claimed position.
     * @param entryPrice The entry price of the position
     * @param exitPrice The exit price of the position
     * @param realizedPnl The realized position pnl (taker side).
     * @param interest The interest paid for the claimed position.
     * @param data Additional data related to the callback.
     */
    function claimPositionCallback(
        Position memory position,
        uint256 entryPrice,
        uint256 exitPrice,
        int256 realizedPnl,
        uint256 interest,
        bytes calldata data
    ) external;
}
