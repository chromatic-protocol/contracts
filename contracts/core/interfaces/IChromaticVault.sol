// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ILendingPool} from "@chromatic-protocol/contracts/core/interfaces/vault/ILendingPool.sol";
import {IVault} from "@chromatic-protocol/contracts/core/interfaces/vault/IVault.sol";

/**
 * @title IChromaticVault
 * @notice Interface for the Chromatic Vault contract.
 */
interface IChromaticVault is IVault, ILendingPool {
    /**
     * @dev Emitted when market earning is accumulated.
     * @param market The address of the market.
     * @param earning The amount of earning accumulated.
     */
    event MarketEarningAccumulated(address indexed market, uint256 earning);

    /**
     * @dev Emitted when maker earning is distributed.
     * @param token The address of the settlement token.
     * @param earning The amount of earning distributed.
     * @param usedKeeperFee The amount of keeper fee used.
     */
    event MakerEarningDistributed(
        address indexed token,
        uint256 indexed earning,
        uint256 indexed usedKeeperFee
    );

    /**
     * @dev Emitted when market earning is distributed.
     * @param market The address of the market.
     * @param earning The amount of earning distributed.
     * @param usedKeeperFee The amount of keeper fee used.
     * @param marketBalance The balance of the market.
     */
    event MarketEarningDistributed(
        address indexed market,
        uint256 indexed earning,
        uint256 indexed usedKeeperFee,
        uint256 marketBalance
    );

    /**
     * @notice Emitted when the vault earning distributor address is set.
     * @param vaultEarningDistributor The vault earning distributor address.
     * @param oldVaultEarningDistributor The old vault earning distributor address.
     */
    event VaultEarningDistributorSet(
        address indexed vaultEarningDistributor,
        address indexed oldVaultEarningDistributor
    );

    function setVaultEarningDistributor(address _earningDistributor) external;

    function pendingMakerEarnings(address token) external view returns (uint256);

    function pendingMarketEarnings(address market) external view returns (uint256);

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
     * @notice Distributes the maker earning for a token to the each markets.
     * @param token The address of the settlement token.
     * @param fee The keeper fee amount.
     * @param keeper The keeper address to receive fee.
     */
    function distributeMakerEarning(address token, uint256 fee, address keeper) external;

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
     * @notice Distributes the market earning for a market to the each bins.
     * @param market The address of the market.
     * @param fee The fee amount.
     * @param keeper The keeper address to receive fee.
     */
    function distributeMarketEarning(address market, uint256 fee, address keeper) external;

    function acquireTradingLock() external;

    function releaseTradingLock() external;
}
