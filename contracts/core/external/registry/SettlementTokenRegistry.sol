// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {InterestRate} from "@usum/core/libraries/InterestRate.sol";

struct SettlementTokenRegistry {
    EnumerableSet.AddressSet _tokens;
    mapping(address => InterestRate.Record[]) _interestRateRecords;
    mapping(address => uint256) _minimumTakerMargins;
    mapping(address => uint256) _flashLoanFeeRates;
    mapping(address => uint24) _uniswapFeeTiers;
}

library SettlementTokenRegistryLib {
    using EnumerableSet for EnumerableSet.AddressSet;
    using InterestRate for InterestRate.Record[];

    modifier registeredOnly(
        SettlementTokenRegistry storage self,
        address token
    ) {
        require(self._tokens.contains(token), "URT"); // UnRegistered Token
        _;
    }

    function register(
        SettlementTokenRegistry storage self,
        address token,
        uint256 minimumTakerMargin,
        uint256 interestRate,
        uint256 flashLoanFeeRate,
        uint24 uniswapFeeTier
    ) external {
        require(self._tokens.add(token), "ART"); // Already Registered Token

        self._interestRateRecords[token].initialize(interestRate);
        self._minimumTakerMargins[token] = minimumTakerMargin;
        self._flashLoanFeeRates[token] = flashLoanFeeRate;
        self._uniswapFeeTiers[token] = uniswapFeeTier;
    }

    function settlmentTokens(
        SettlementTokenRegistry storage self
    ) external view returns (address[] memory) {
        return self._tokens.values();
    }

    function isRegistered(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (bool) {
        return self._tokens.contains(token);
    }

    function getMinimumTakerMargin(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (uint256) {
        return self._minimumTakerMargins[token];
    }

    function setMinimumTakerMargin(
        SettlementTokenRegistry storage self,
        address token,
        uint256 minimumTakerMargin
    ) external {
        self._minimumTakerMargins[token] = minimumTakerMargin;
    }

    function getFlashLoanFeeRate(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (uint256) {
        return self._flashLoanFeeRates[token];
    }

    function setFlashLoanFeeRate(
        SettlementTokenRegistry storage self,
        address token,
        uint256 flashLoanFeeRate
    ) external {
        self._flashLoanFeeRates[token] = flashLoanFeeRate;
    }

    function getUniswapFeeTier(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (uint24) {
        return self._uniswapFeeTiers[token];
    }

    function setUniswapFeeTier(
        SettlementTokenRegistry storage self,
        address token,
        uint24 uniswapFeeTier
    ) external {
        self._uniswapFeeTiers[token] = uniswapFeeTier;
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
