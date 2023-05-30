// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

interface IUSUMLiquidityCallback {
    function addLiquidityCallback(address settlementToken, address vault, bytes calldata data) external;

    function claimLpTokenCallback(uint256 receiptId, address recipient, bytes calldata data) external;

    function removeLiquidityCallback(address lpToken, bytes calldata data) external;
}
