// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IUSUMFlashLoanCallback {
    function flashLoanCallback(uint256 fee, bytes calldata data) external;
}
