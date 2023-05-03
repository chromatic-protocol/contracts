// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IOracleProviderRegistry {
    event OracleProviderRegistered(address oracleProvider);
    event OracleProviderUnregistered(address oracleProvider);

    function registerOracleProvider(address oracleProvider) external;

    function unregisterOracleProvider(address oracleProvider) external;

    function registeredOracleProviders()
        external
        view
        returns (address[] memory);

    function isRegisteredOracleProvider(
        address oracleProvider
    ) external view returns (bool);
}