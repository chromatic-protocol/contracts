// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {ClaimPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTrade.sol";

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
     * @param claimInfo The pnl related information of the claim
     * @param data Additional data related to the callback.
     */
    function claimPositionCallback(
        Position memory position,
        ClaimPositionInfo memory claimInfo,
        bytes calldata data
    ) external;
}
