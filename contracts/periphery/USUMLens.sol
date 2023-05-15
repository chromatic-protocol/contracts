// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IUSUMLens} from "@usum/periphery/interfaces/IUSUMLens.sol";


contract USUMLens is IUSUMLens {

    /// add liquidity
    function estimatedLiquidity(
        address market,
        int16 tradingFeeRate,
        uint256 amount
    ) external override view returns (uint256 liquidity) {
        liquidity = IUSUMMarket(market).calcLiquidity(tradingFeeRate, amount);
    }

    /// remove liquidity
    function estimatedAmount(
        address market,
        int16 tradingFeeRate,
        uint256 liquidity
    ) external override view returns (uint256 amount) {
        amount = IUSUMMarket(market).calcAmount(tradingFeeRate, liquidity);
    }

    function getSlotMarginsTotal(
        address market,
        int16[] calldata tradingFeeRates
    ) external override returns (uint256[] memory amounts) {
        amounts = new uint256[](tradingFeeRates.length);
        for (uint i = 0; i < tradingFeeRates.length; i++) {
            amounts[i] = IUSUMMarket(market).getSlotMarginTotal(
                tradingFeeRates[i]
            );
        }
    }

    function getSlotMarginsUnused(
        address market,
        int16[] calldata tradingFeeRates
    ) external override returns (uint256[] memory amounts) {
        amounts = new uint256[](tradingFeeRates.length);
        for (uint i = 0; i < tradingFeeRates.length; i++) {
            amounts[i] = IUSUMMarket(market).getSlotMarginUnused(
                tradingFeeRates[i]
            );
        }
    }

    function balanceOfBatch(
        address market,
        address[] calldata owners,
        uint256[] calldata ids
    ) external override view returns (uint256[] memory) {
        return IERC1155(market).balanceOfBatch(owners, ids);
    }
}
