// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticLiquidityCallback {
    function addLiquidityCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external;

    function claimLiquidityCallback(uint256 receiptId, bytes calldata data) external;

    function removeLiquidityCallback(
        address clbToken,
        uint256 clbTokenId,
        bytes calldata data
    ) external;

    function withdrawLiquidityCallback(uint256 receiptId, bytes calldata data) external;
}
