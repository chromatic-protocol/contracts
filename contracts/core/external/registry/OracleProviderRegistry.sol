// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Errors} from "@usum/core/libraries/Errors.sol";

struct OracleProviderRegistry {
    EnumerableSet.AddressSet _oracleProviders;
}

/**
 * @title OracleProviderRegistry
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
    function register(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external {
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
    function unregister(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external {
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
}
