// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Position} from "@usum/core/libraries/Position.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";

interface IUSUMLens {
    function getSlotMarginsTotal(
        address market,
        int16[] calldata tradingFeeRates
    ) external returns (uint256[] memory amounts);

    function getSlotMarginsUnused(
        address market,
        int16[] calldata tradingFeeRates
    ) external returns (uint256[] memory amounts);

    function estimatedLiquidity(
        address market,
        int16 feeRate,
        uint256 amount
    ) external returns (uint256 liquidity);

    // removeLiquidity 예상
    function estimatedAmount(
        address market,
        int16 feeRate,
        uint256 liquidity
    ) external returns (uint256 amount);

    function balanceOfBatch(
        address market,
        address[] calldata owners,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);
}
