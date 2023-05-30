// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

interface IUSUMLiquidity {
    event AddLiquidity(
        address indexed recipient,
        int16 indexed tradingFeeRate,
        uint256 tokenId,
        uint256 amount,
        uint256 lpTokenAmount
    );

    event RemoveLiquidity(
        address indexed recipient,
        int16 indexed tradingFeeRate,
        uint256 tokenId,
        uint256 amount,
        uint256 lpTokenAmount
    );

    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (uint256 lpTokenAmount);

    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (uint256 amount);

    function getSlotLiquidities(int16[] memory tradingFeeRate) external returns (uint256[] memory amounts);

    function getSlotFreeLiquidities(int16[] memory tradingFeeRate) external returns (uint256[] memory amounts);

    function distributeEarningToSlots(uint256 earning, uint256 marketBalance) external;

    function calculateLpTokenMinting(int16 tradingFeeRate, uint256 amount) external view returns (uint256);

    function calculateLpTokenValue(int16 tradingFeeRate, uint256 lpTokenAmount) external view returns (uint256);
}
