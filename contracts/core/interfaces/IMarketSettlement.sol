// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IMarketSettlement
 * @dev Interface for the Market settlement task contract.
 */
interface IMarketSettlement {
    /**
     * @notice Creates a settlement task for a given market.
     * @param market The address of the chromatic market contract to be settled.
     */
    function createSettlementTask(address market) external;

    /**
     * @notice Cancels a settlement task for a given market.
     * @param market The address of the chromatic market contract for which to cancel the settlement task.
     */
    function cancelSettlementTask(address market) external;

    /**
     * @notice Resolves the settlement of a market.
     * @dev This function is called by the automation system.
     * @param market The address of the market contract.
     * @param extraData passed by keeper for passing offchain data
     * @return canExec Whether the settlement can be executed.
     * @return execPayload The encoded function call to execute the settlement.
     */
    function resolveSettlement(
        address market,
        bytes calldata extraData
    ) external view returns (bool canExec, bytes memory execPayload);

    /**
     * @notice Settles a market.
     * @param market The address of the market contract.
     */
    function settle(address market) external;

    /**
     * @notice Updates the price using off-chain data.
     * @param market The address of the market contract.
     * @param extraData passed by keeper for passing offchain data
     */
    function updatePrice(address market, bytes calldata extraData) external;
}
