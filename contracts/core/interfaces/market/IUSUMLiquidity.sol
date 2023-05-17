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

    function getSlotMarginsTotal(
        int16[] calldata tradingFeeRate
    ) external returns (uint256[] memory amounts);

    function getSlotMarginsUnused(
        int16[] calldata tradingFeeRate
    ) external returns (uint256[] memory amounts);

    function distributeEarningToSlots(
        uint256 earning,
        uint256 marketBalance
    ) external;

    function estimatedLiquidity(
        int16 tradingFeeRate,
        uint256 amount
    ) external view returns (uint256);

    function estimatedAmount(
        int16 tradingFeeRate,
        uint256 liquidity
    ) external view returns (uint256);
}
