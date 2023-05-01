// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface ISettlementTokenRegistry {
    event SettlementTokenRegistered(address indexed token);
    event InterestRateRecordAppended(
        address indexed token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    );
    event LastInterestRateRecordRemoved(
        address indexed token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    );

    function registerSettlementToken(address token) external;

    function registeredSettlementTokens()
        external
        view
        returns (address[] memory);

    function isRegisteredSettlementToken(address token) external view returns (bool);

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

    function calculateInterest(
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to, // timestamp (exclusive)
        Math.Rounding rounding
    ) external view returns (uint256);
}
