// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

struct OracleProviderRegistry {
    EnumerableSet.AddressSet _oracleProviders;
}

library OracleProviderRegistryLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    error AlreadyRegistered();

    function register(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external {
        if (self._oracleProviders.contains(oracleProvider))
            revert AlreadyRegistered();

        self._oracleProviders.add(oracleProvider);
    }

    function unregister(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external {
        self._oracleProviders.remove(oracleProvider);
    }

    function isRegistered(
        OracleProviderRegistry storage self,
        address oracleProvider
    ) external view returns (bool) {
        return self._oracleProviders.contains(oracleProvider);
    }
}
