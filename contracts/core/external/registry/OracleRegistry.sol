// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

struct OracleRegistry {
    EnumerableSet.AddressSet _oracleProviders;
}

library OracleRegistryLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    error AlreadyRegistered();

    function register(
        OracleRegistry storage self,
        address oracleProvider
    ) external {
        if (self._oracleProviders.contains(oracleProvider))
            revert AlreadyRegistered();

        self._oracleProviders.add(oracleProvider);
    }

    function unregister(
        OracleRegistry storage self,
        address oracleProvider
    ) external {
        self._oracleProviders.remove(oracleProvider);
    }

    function isRegistered(
        OracleRegistry storage self,
        address oracleProvider
    ) external view returns (bool) {
        return self._oracleProviders.contains(oracleProvider);
    }
}
