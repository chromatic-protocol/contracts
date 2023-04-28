// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {InterestRate} from "@usum/core/libraries/InterestRate.sol";

struct SettlementTokenRegistry {
    EnumerableSet.AddressSet _tokens;
    mapping(address => InterestRate.Record[]) _interestRateRecords;
}

library SettlementTokenRegistryLib {
    using EnumerableSet for EnumerableSet.AddressSet;
    using InterestRate for InterestRate.Record[];

    error AlreadyRegisteredToken();
    error UnregisteredToken();

    modifier registeredOnly(
        SettlementTokenRegistry storage self,
        address token
    ) {
        if (!self._tokens.contains(token)) {
            revert UnregisteredToken();
        }
        _;
    }

    function register(
        SettlementTokenRegistry storage self,
        address token
    ) external {
        if (!self._tokens.add(token)) {
            revert AlreadyRegisteredToken();
        }

        self._interestRateRecords[token].initialize();
    }

    function isRegistered(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (bool) {
        return self._tokens.contains(token);
    }

    function appendInterestRateRecord(
        SettlementTokenRegistry storage self,
        address token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) external registeredOnly(self, token) {
        getInterestRateRecords(self, token).appendRecord(
            annualRateBPS,
            beginTimestamp
        );
    }

    function removeLastInterestRateRecord(
        SettlementTokenRegistry storage self,
        address token
    )
        external
        registeredOnly(self, token)
        returns (bool removed, InterestRate.Record memory record)
    {
        (removed, record) = getInterestRateRecords(self, token)
            .removeLastRecord();
    }

    function currentInterestRate(
        SettlementTokenRegistry storage self,
        address token
    )
        external
        view
        registeredOnly(self, token)
        returns (uint256 annualRateBPS)
    {
        (InterestRate.Record memory record, ) = getInterestRateRecords(
            self,
            token
        ).findRecordAt(block.timestamp);
        return record.annualRateBPS;
    }

    function calculateInterest(
        SettlementTokenRegistry storage self,
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to, // timestamp (exclusive)
        Math.Rounding rounding
    ) external view registeredOnly(self, token) returns (uint256) {
        return
            getInterestRateRecords(self, token).calculateInterest(
                amount,
                from,
                to,
                rounding
            );
    }

    function getInterestRateRecords(
        SettlementTokenRegistry storage self,
        address token
    ) internal view returns (InterestRate.Record[] storage) {
        return self._interestRateRecords[token];
    }
}
