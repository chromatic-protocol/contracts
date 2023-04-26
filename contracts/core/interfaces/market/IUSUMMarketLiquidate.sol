// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IUSUMMarketLiquidate {
    function transferKeeperFee(
        address keeper,
        uint256 fee,
        uint256 positionId
    ) external returns (uint256);

    function resolveLiquidation(
        uint256 positionId
    ) external view returns (bool);

    function liquidate(uint256 positionId, uint256 usedKeeperFee) external;
}
