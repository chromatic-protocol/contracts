// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IChromaticFlashLoanCallback
 * @dev Interface for a contract that handles flash loan callbacks in the Chromatic protocol.
 *      Flash loans are loans that are borrowed and repaid within a single transaction.
 *      This interface defines the function signature for the flash loan callback.
 */
interface IChromaticFlashLoanCallback {
    /**
     * @notice Handles the flash loan callback after a flash loan has been executed.
     * @param fee The fee amount charged for the flash loan.
     * @param data Additional data associated with the flash loan.
     */
    function flashLoanCallback(uint256 fee, bytes calldata data) external;
}
