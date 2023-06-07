// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

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
     * @param positionId The ID of the claimed position.
     * @param data Additional data related to the callback.
     */
    function claimPositionCallback(uint256 positionId, bytes calldata data) external;
}
