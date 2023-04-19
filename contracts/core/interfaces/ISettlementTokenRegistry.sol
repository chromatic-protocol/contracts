// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ISettlementTokenRegistry {

    function dao() external view returns (address);

    function registerSettlementToken(address token) external;

    function isRegisteredSettlementToken(
        address token
    ) external view returns (bool);

    function appendInterestRateRecord(
        address token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) external;

    function removeLastInterestRateRecord(address token) external;

    function currentInterestRate(address token) external view returns (uint256);

    function calculateInterest(
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to // timestamp (exclusive)
    ) external view returns (uint256);
}
