// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IUSUMMarketLiquidate {
    function checkLiquidation(uint256 positionId) external view returns (bool);

    function liquidate(
        uint256 positionId,
        address keeper,
        uint256 keeperFee
    ) external;
}
