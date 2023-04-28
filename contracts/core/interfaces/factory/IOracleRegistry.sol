// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IOracleRegistry {
    event OracleProviderRegistered(address oracleProvider);
    event OracleProviderUnregistered(address oracleProvider);

    function registerOracleProvider(address oracleProvider) external;

    function unregisterOracleProvider(address oracleProvider) external;

    function isRegisteredOracleProvider(
        address oracleProvider
    ) external view returns (bool);
}
