// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IInterestCalculator {
    function calculateInterest(
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to // timestamp (exclusive)
    ) external view returns (uint256);
}
