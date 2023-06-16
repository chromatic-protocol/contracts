// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {InterestRate} from "@chromatic-protocol/contracts/core/libraries/InterestRate.sol";
import {Errors} from "@chromatic-protocol/contracts/core/libraries/Errors.sol";

/**
 * @title SettlementTokenRegistry
 * @dev A registry for managing settlement tokens and their associated parameters.
 */
struct SettlementTokenRegistry {
    /// @dev Set of registered settlement tokens
    EnumerableSet.AddressSet _tokens;
    /// @dev Mapping of settlement tokens to their interest rate records
    mapping(address => InterestRate.Record[]) _interestRateRecords;
    /// @dev Mapping of settlement tokens to their minimum margins
    mapping(address => uint256) _minimumMargins;
    /// @dev Mapping of settlement tokens to their flash loan fee rates
    mapping(address => uint256) _flashLoanFeeRates;
    /// @dev Mapping of settlement tokens to their earning distribution thresholds
    mapping(address => uint256) _earningDistributionThresholds;
    /// @dev Mapping of settlement tokens to their Uniswap fee tiers
    mapping(address => uint24) _uniswapFeeTiers;
}

/**
 * @title SettlementTokenRegistryLib
 * @notice Library for managing the settlement token registry.
 */
library SettlementTokenRegistryLib {
    using EnumerableSet for EnumerableSet.AddressSet;
    using InterestRate for InterestRate.Record[];

    /**
     * @notice Modifier to check if a token is registered in the settlement token registry.
     * @dev Throws an error if the token is not registered.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the token to check.
     */
    modifier registeredOnly(SettlementTokenRegistry storage self, address token) {
        require(self._tokens.contains(token), Errors.UNREGISTERED_TOKEN);
        _;
    }

    /**
     * @notice Registers a token in the settlement token registry.
     * @dev Throws an error if the token is already registered.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the token to register.
     * @param minimumMargin The minimum margin for the token.
     * @param interestRate The initial interest rate for the token.
     * @param flashLoanFeeRate The flash loan fee rate for the token.
     * @param earningDistributionThreshold The earning distribution threshold for the token.
     * @param uniswapFeeTier The Uniswap fee tier for the token.
     */
    function register(
        SettlementTokenRegistry storage self,
        address token,
        uint256 minimumMargin,
        uint256 interestRate,
        uint256 flashLoanFeeRate,
        uint256 earningDistributionThreshold,
        uint24 uniswapFeeTier
    ) external {
        require(self._tokens.add(token), Errors.ALREADY_REGISTERED_TOKEN);

        self._interestRateRecords[token].initialize(interestRate);
        self._minimumMargins[token] = minimumMargin;
        self._flashLoanFeeRates[token] = flashLoanFeeRate;
        self._earningDistributionThresholds[token] = earningDistributionThreshold;
        self._uniswapFeeTiers[token] = uniswapFeeTier;
    }

    /**
     * @notice Returns an array of all registered settlement tokens.
     * @param self The SettlementTokenRegistry storage.
     * @return An array of addresses representing the registered settlement tokens.
     */
    function settlementTokens(
        SettlementTokenRegistry storage self
    ) external view returns (address[] memory) {
        return self._tokens.values();
    }

    /**
     * @notice Checks if a token is registered in the settlement token registry.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the token to check.
     * @return bool Whether the token is registered.
     */
    function isRegistered(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (bool) {
        return self._tokens.contains(token);
    }

    /**
     * @notice Retrieves the minimum margin for a asettlement token.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the asettlement token.
     * @return uint256 The minimum margin for the asettlement token.
     */
    function getMinimumMargin(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (uint256) {
        return self._minimumMargins[token];
    }

    /**
     * @notice Sets the minimum margin for asettlement token.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @param minimumMargin The new minimum margin for the settlement token.
     */
    function setMinimumMargin(
        SettlementTokenRegistry storage self,
        address token,
        uint256 minimumMargin
    ) external {
        self._minimumMargins[token] = minimumMargin;
    }

    /**
     * @notice Retrieves the flash loan fee rate for a settlement token.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @return uint256 The flash loan fee rate for the settlement token.
     */
    function getFlashLoanFeeRate(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (uint256) {
        return self._flashLoanFeeRates[token];
    }

    /**
     * @notice Sets the flash loan fee rate for a settlement token.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @param flashLoanFeeRate The new flash loan fee rate for the settlement token.
     */
    function setFlashLoanFeeRate(
        SettlementTokenRegistry storage self,
        address token,
        uint256 flashLoanFeeRate
    ) external {
        self._flashLoanFeeRates[token] = flashLoanFeeRate;
    }

    /**
     * @notice Retrieves the earning distribution threshold for a settlement token.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @return uint256 The earning distribution threshold for the token.
     */
    function getEarningDistributionThreshold(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (uint256) {
        return self._earningDistributionThresholds[token];
    }

    /**
     * @notice Sets the earning distribution threshold for a settlement token.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @param earningDistributionThreshold The new earning distribution threshold for the settlement token.
     */
    function setEarningDistributionThreshold(
        SettlementTokenRegistry storage self,
        address token,
        uint256 earningDistributionThreshold
    ) external {
        self._earningDistributionThresholds[token] = earningDistributionThreshold;
    }

    /**
     * @notice Retrieves the Uniswap fee tier for a settlement token.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @return uint24 The Uniswap fee tier for the settlement token.
     */
    function getUniswapFeeTier(
        SettlementTokenRegistry storage self,
        address token
    ) external view returns (uint24) {
        return self._uniswapFeeTiers[token];
    }

    /**
     * @notice Sets the Uniswap fee tier for a settlement token.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @param uniswapFeeTier The new Uniswap fee tier for the settlement token.
     */
    function setUniswapFeeTier(
        SettlementTokenRegistry storage self,
        address token,
        uint24 uniswapFeeTier
    ) external {
        self._uniswapFeeTiers[token] = uniswapFeeTier;
    }

    /**
     * @notice Appends an interest rate record for a settlement token.
     * @dev Throws an error if the settlement token is not registered.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @param annualRateBPS The annual interest rate in basis points.
     * @param beginTimestamp The timestamp when the interest rate begins.
     */
    function appendInterestRateRecord(
        SettlementTokenRegistry storage self,
        address token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) external registeredOnly(self, token) {
        getInterestRateRecords(self, token).appendRecord(annualRateBPS, beginTimestamp);
    }

    /**
     * @notice Removes the last interest rate record for a settlement token.
     * @dev The current time must be less than the begin timestamp of the last record.
     *      Otherwise throws an error with the message `INTEREST_RATE_ALREADY_APPLIED`.
     * @dev Throws an error if the settlement token is not registered.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @return removed Whether the removal was successful
     * @return record The removed interest rate record.
     */
    function removeLastInterestRateRecord(
        SettlementTokenRegistry storage self,
        address token
    )
        external
        registeredOnly(self, token)
        returns (bool removed, InterestRate.Record memory record)
    {
        (removed, record) = getInterestRateRecords(self, token).removeLastRecord();
    }

    /**
     * @notice Retrieves the current interest rate for a settlement token.
     * @dev Throws an error if the settlement token is not registered.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @return annualRateBPS The current annual interest rate in basis points.
     */
    function currentInterestRate(
        SettlementTokenRegistry storage self,
        address token
    ) external view registeredOnly(self, token) returns (uint256 annualRateBPS) {
        (InterestRate.Record memory record, ) = getInterestRateRecords(self, token).findRecordAt(
            block.timestamp
        );
        return record.annualRateBPS;
    }

    /**
     * @notice Calculates the interest accrued for a settlement token within a specified time range.
     * @dev Throws an error if the token is not registered.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @param amount The amount of settlement tokens to calculate interest for.
     * @param from The starting timestamp of the interest calculation (inclusive).
     * @param to The ending timestamp of the interest calculation (exclusive).
     * @return uint256 The calculated interest amount.
     */
    function calculateInterest(
        SettlementTokenRegistry storage self,
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to // timestamp (exclusive)
    ) external view registeredOnly(self, token) returns (uint256) {
        return getInterestRateRecords(self, token).calculateInterest(amount, from, to);
    }

    /**
     * @notice Retrieves the array of interest rate records for a settlement token.
     * @param self The SettlementTokenRegistry storage.
     * @param token The address of the settlement token.
     * @return The array of interest rate records.
     */
    function getInterestRateRecords(
        SettlementTokenRegistry storage self,
        address token
    ) public view returns (InterestRate.Record[] storage) {
        return self._interestRateRecords[token];
    }
}
