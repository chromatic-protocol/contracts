// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

struct OracleProviderRegistry {
    EnumerableSet.AddressSet _oracleProviders;
}

library OracleProviderRegistryLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    function register(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external {
        require(!self._oracleProviders.contains(oracleProvider), "ARO"); // Already Registered Oracle provider

        self._oracleProviders.add(oracleProvider);
    }

    function unregister(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external {
        self._oracleProviders.remove(oracleProvider);
    }

    function oracleProviders(
        OracleProviderRegistry storage self
    ) external view returns (address[] memory) {
        return self._oracleProviders.values();
    }

    function isRegistered(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external view returns (bool) {
        return self._oracleProviders.contains(oracleProvider);
    }
}
