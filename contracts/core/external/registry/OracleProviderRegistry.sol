// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Errors} from "@chromatic-protocol/contracts/core/libraries/Errors.sol";

/**
 * @title OracleProviderRegistry
 * @dev A registry for managing oracle providers.
 */
struct OracleProviderRegistry {
    /// @dev Set of registered oracle providers
    EnumerableSet.AddressSet _oracleProviders;
    mapping(address => uint8) _oracleProviderLevels;
}

/**
 * @title OracleProviderRegistryLib
 * @notice Library for managing a registry of oracle providers.
 */
library OracleProviderRegistryLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice Registers an oracle provider in the registry.
     * @dev Throws an error if the oracle provider is already registered.
     * @param self The OracleProviderRegistry storage.
     * @param oracleProvider The address of the oracle provider to register.
     */
    function register(OracleProviderRegistry storage self, address oracleProvider) external {
        require(
            !self._oracleProviders.contains(oracleProvider),
            Errors.ALREADY_REGISTERED_ORACLE_PROVIDER
        );

        self._oracleProviders.add(oracleProvider);
    }

    /**
     * @notice Unregisters an oracle provider from the registry.
     * @param self The OracleProviderRegistry storage.
     * @param oracleProvider The address of the oracle provider to unregister.
     */
    function unregister(OracleProviderRegistry storage self, address oracleProvider) external {
        self._oracleProviders.remove(oracleProvider);
    }

    /**
     * @notice Returns an array of all registered oracle providers.
     * @param self The OracleProviderRegistry storage.
     * @return oracleProviders An array of addresses representing the registered oracle providers.
     */
    function oracleProviders(
        OracleProviderRegistry storage self
    ) external view returns (address[] memory) {
        return self._oracleProviders.values();
    }

    /**
     * @notice Checks if an oracle provider is registered in the registry.
     * @param self The OracleProviderRegistry storage.
     * @param oracleProvider The address of the oracle provider to check.
     * @return bool Whether the oracle provider is registered.
     */
    function isRegistered(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external view returns (bool) {
        return self._oracleProviders.contains(oracleProvider);
    }

    /**
     * @notice Retrieves the level of an oracle provider in the registry.
     * @param self The storage reference to the OracleProviderRegistry.
     * @param oracleProvider The address of the oracle provider.
     * @return The level of the oracle provider.
     */
    function getOracleProviderLevel(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external view returns (uint8) {
        return self._oracleProviderLevels[oracleProvider];
    }

    /**
     * @notice Sets the level of an oracle provider in the registry.
     * @dev The level must be either 0 or 1, and the max leverage must be x10 for level 0 or x20 for level 1.
     * @param self The storage reference to the OracleProviderRegistry.
     * @param oracleProvider The address of the oracle provider.
     * @param level The new level to be set for the oracle provider.
     */
    function setOracleProviderLevel(
        OracleProviderRegistry storage self,
        address oracleProvider,
        uint8 level
    ) external {
        self._oracleProviderLevels[oracleProvider] = level;
    }
}
