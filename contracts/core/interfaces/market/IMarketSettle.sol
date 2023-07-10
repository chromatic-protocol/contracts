// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IMarketSettle
 * @dev Interface for market settlement.
 */
interface IMarketSettle {
    /**
     * @notice Executes the settlement process for the Chromatic market.
     * @dev This function is called to settle the market.
     */
    function settle() external;
}
