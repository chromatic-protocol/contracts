// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IInterestCalculator {
    function calculateInterest(
        uint256 amount,
        uint256 from,
        uint256 to
    ) external view returns (uint256);
}
