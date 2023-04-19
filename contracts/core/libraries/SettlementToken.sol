// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {InterestRateLib, Record} from "@usum/core/libraries/InterestRate.sol";

struct Registry {
    EnumerableSet.AddressSet _tokens;
    mapping(address => Record[]) _interestRateRecords;
}

using SettlementToken for Registry global;

library SettlementToken {
    using EnumerableSet for EnumerableSet.AddressSet;
    using InterestRateLib for Record[];

    function register(
        Registry storage self,
        address token
    ) internal returns (bool) {
        if (self._tokens.add(token)) {
            self._interestRateRecords[token].initialize();
            return true;
        }

        return false;
    }
    function contains(
        Registry storage self,
        address token
    ) internal view returns (bool) {
        return self._tokens.contains(token);
    }

    function length(Registry storage self) internal view returns (uint256) {
        return self._tokens.length();
    }

    function getInterestRateRecords(
        Registry storage self,
        address token
    ) internal view returns (Record[] storage) {
        return self._interestRateRecords[token];
    }
}
