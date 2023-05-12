// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

interface IUSUMLiquidity {
    event AddLiquidity(
        address indexed recipient,
        int16 indexed tradingFeeRate,
        uint256 tokenId,
        uint256 amount,
        uint256 liquidity
    );

    event RemoveLiquidity(
        address indexed recipient,
        int16 indexed tradingFeeRate,
        uint256 tokenId,
        uint256 amount,
        uint256 liquidity
    );

    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (uint256 liquidity);

    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (uint256 amount);

    function getSlotMarginTotal(
        int16 tradingFeeRate
    ) external returns (uint256 amount);

    function getSlotMarginUnused(
        int16 tradingFeeRate
    ) external returns (uint256 amount);

    function distributeEarningToSlots(
        uint256 earning,
        uint256 marketBalance
    ) external;
}
