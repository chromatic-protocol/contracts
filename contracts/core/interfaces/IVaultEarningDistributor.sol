// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IVaultEarningDistributor {
    /**
     * @notice Creates a maker earning distribution task for a token.
     * @param token The address of the settlement token.
     */
    function createMakerEarningDistributionTask(address token) external;

    /**
     * @notice Cancels a maker earning distribution task for a token.
     * @param token The address of the settlement token.
     */
    function cancelMakerEarningDistributionTask(address token) external;

    /**
     * @notice Resolves the maker earning distribution for a specific token.
     * @param token The address of the settlement token.
     * @return canExec True if the distribution can be executed, otherwise False.
     * @return execPayload The payload for executing the distribution.
     */
    function resolveMakerEarningDistribution(
        address token
    ) external view returns (bool canExec, bytes memory execPayload);

    /**
     * @notice Distributes the maker earning for a token to the each markets.
     * @param token The address of the settlement token.
     */
    function distributeMakerEarning(address token) external;

    /**
     * @notice Creates a market earning distribution task for a market.
     * @param market The address of the market.
     */
    function createMarketEarningDistributionTask(address market) external;

    /**
     * @notice Cancels a market earning distribution task for a market.
     * @param market The address of the market.
     */
    function cancelMarketEarningDistributionTask(address market) external;

    /**
     * @notice Resolves the market earning distribution for a market.
     * @param market The address of the market.
     * @return canExec True if the distribution can be executed.
     * @return execPayload The payload for executing the distribution.
     */
    function resolveMarketEarningDistribution(
        address market
    ) external view returns (bool canExec, bytes memory execPayload);

    /**
     * @notice Distributes the market earning for a market to the each bins.
     * @param market The address of the market.
     */
    function distributeMarketEarning(address market) external;
}
