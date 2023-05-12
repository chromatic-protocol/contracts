// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

interface IInterestCalculator {
    function calculateInterest(
        uint256 amount,
        uint256 from,
        uint256 to
    ) external view returns (uint256);

    function calculateInterest(
        uint256 amount,
        uint256 from,
        uint256 to,
        Math.Rounding rounding // use Rouding.Up to deduct accumulated accrued interest
    ) external view returns (uint256);
}
