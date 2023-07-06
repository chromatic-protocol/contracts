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
    mapping(address => uint32) _minStopLossBPSs;
    mapping(address => uint32) _maxStopLossBPSs;
    mapping(address => uint32) _minTakeProfitBPSs;
    mapping(address => uint32) _maxTakeProfitBPSs;
    mapping(address => uint8) _leverageLevels;
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
     * @param minStopLossBPS The minimum stop-loss basis points.
     * @param maxStopLossBPS The maximum stop-loss basis points.
     * @param minTakeProfitBPS The minimum take-profit basis points.
     * @param maxTakeProfitBPS The maximum take-profit basis points.
     * @param leverageLevel The leverage level of the oracle provider.
     */
    function register(
        OracleProviderRegistry storage self,
        address oracleProvider,
        uint32 minStopLossBPS,
        uint32 maxStopLossBPS,
        uint32 minTakeProfitBPS,
        uint32 maxTakeProfitBPS,
        uint8 leverageLevel
    ) external {
        require(
            !self._oracleProviders.contains(oracleProvider),
            Errors.ALREADY_REGISTERED_ORACLE_PROVIDER
        );

        self._oracleProviders.add(oracleProvider);
        self._minStopLossBPSs[oracleProvider] = minStopLossBPS;
        self._maxStopLossBPSs[oracleProvider] = maxStopLossBPS;
        self._minTakeProfitBPSs[oracleProvider] = minTakeProfitBPS;
        self._maxTakeProfitBPSs[oracleProvider] = maxTakeProfitBPS;
        self._leverageLevels[oracleProvider] = leverageLevel;
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
     * @notice Retrieves the properties of an oracle provider.
     * @param self The OracleProviderRegistry storage.
     * @param oracleProvider The address of the oracle provider.
     * @return minStopLossBPS The minimum stop-loss basis points.
     * @return maxStopLossBPS The maximum stop-loss basis points.
     * @return minTakeProfitBPS The minimum take-profit basis points.
     * @return maxTakeProfitBPS The maximum take-profit basis points.
     * @return leverageLevel The leverage level of the oracle provider.
     */
    function getOracleProviderProperties(
        OracleProviderRegistry storage self,
        address oracleProvider
    )
        external
        view
        returns (
            uint32 minStopLossBPS,
            uint32 maxStopLossBPS,
            uint32 minTakeProfitBPS,
            uint32 maxTakeProfitBPS,
            uint8 leverageLevel
        )
    {
        minStopLossBPS = self._minStopLossBPSs[oracleProvider];
        maxStopLossBPS = self._maxStopLossBPSs[oracleProvider];
        minTakeProfitBPS = self._minTakeProfitBPSs[oracleProvider];
        maxTakeProfitBPS = self._maxTakeProfitBPSs[oracleProvider];
        leverageLevel = self._leverageLevels[oracleProvider];
    }

    /**
     * @notice Sets the range for stop-loss basis points for an oracle provider.
     * @param self The OracleProviderRegistry storage.
     * @param oracleProvider The address of the oracle provider.
     * @param minStopLossBPS The minimum stop-loss basis points.
     * @param maxStopLossBPS The maximum stop-loss basis points.
     */
    function setStopLossBPSRange(
        OracleProviderRegistry storage self,
        address oracleProvider,
        uint32 minStopLossBPS,
        uint32 maxStopLossBPS
    ) external {
        self._minStopLossBPSs[oracleProvider] = minStopLossBPS;
        self._maxStopLossBPSs[oracleProvider] = maxStopLossBPS;
    }

    /**
     * @notice Sets the range for take-profit basis points for an oracle provider.
     * @param self The OracleProviderRegistry storage.
     * @param oracleProvider The address of the oracle provider.
     * @param minTakeProfitBPS The minimum take-profit basis points.
     * @param maxTakeProfitBPS The maximum take-profit basis points.
     */
    function setTakeProfitBPSRange(
        OracleProviderRegistry storage self,
        address oracleProvider,
        uint32 minTakeProfitBPS,
        uint32 maxTakeProfitBPS
    ) external {
        self._minTakeProfitBPSs[oracleProvider] = minTakeProfitBPS;
        self._maxTakeProfitBPSs[oracleProvider] = maxTakeProfitBPS;
    }

    /**
     * @notice Sets the leverage level of an oracle provider in the registry.
     * @dev The leverage level must be either 0 or 1, and the max leverage must be x10 for level 0 or x20 for level 1.
     * @param self The storage reference to the OracleProviderRegistry.
     * @param oracleProvider The address of the oracle provider.
     * @param leverageLevel The new leverage level to be set for the oracle provider.
     */
    function setLeverageLevel(
        OracleProviderRegistry storage self,
        address oracleProvider,
        uint8 leverageLevel
    ) external {
        self._leverageLevels[oracleProvider] = leverageLevel;
    }
}
