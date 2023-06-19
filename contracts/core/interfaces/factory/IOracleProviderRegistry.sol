// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IOracleProviderRegistry
 * @dev Interface for the Oracle Provider Registry contract.
 */
interface IOracleProviderRegistry {
    /**
     * @dev Emitted when a new oracle provider is registered.
     * @param oracleProvider The address of the registered oracle provider.
     */
    event OracleProviderRegistered(address indexed oracleProvider);

    /**
     * @dev Emitted when an oracle provider is unregistered.
     * @param oracleProvider The address of the unregistered oracle provider.
     */
    event OracleProviderUnregistered(address indexed oracleProvider);

    /**
     * @dev Emitted when the level of an oracle provider is set.
     * @param oracleProvider The address of the oracle provider.
     * @param level The new level set for the oracle provider.
     */
    event SetOracleProviderLevel(address indexed oracleProvider, uint8 indexed level);

    /**
     * @notice Registers an oracle provider.
     * @param oracleProvider The address of the oracle provider to register.
     */
    function registerOracleProvider(address oracleProvider) external;

    /**
     * @notice Unregisters an oracle provider.
     * @param oracleProvider The address of the oracle provider to unregister.
     */
    function unregisterOracleProvider(address oracleProvider) external;

    /**
     * @notice Gets the registered oracle providers.
     * @return An array of registered oracle provider addresses.
     */
    function registeredOracleProviders() external view returns (address[] memory);

    /**
     * @notice Checks if an oracle provider is registered.
     * @param oracleProvider The address of the oracle provider to check.
     * @return A boolean indicating if the oracle provider is registered.
     */
    function isRegisteredOracleProvider(address oracleProvider) external view returns (bool);

    /**
     * @notice Retrieves the level of an oracle provider in the registry.
     * @param oracleProvider The address of the oracle provider.
     * @return The level of the oracle provider.
     */
    function getOracleProviderLevel(address oracleProvider) external view returns (uint8);

    /**
     * @notice Sets the level of an oracle provider in the registry.
     * @dev The level must be either 0 or 1, and the max leverage must be x10 for level 0 or x20 for level 1.
     * @param oracleProvider The address of the oracle provider.
     * @param level The new level to be set for the oracle provider.
     */
    function setOracleProviderLevel(address oracleProvider, uint8 level) external;
}
