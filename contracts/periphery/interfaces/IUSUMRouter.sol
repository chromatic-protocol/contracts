// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IUSUMLiquidityCallback} from "@usum/core/interfaces/callback/IUSUMLiquidityCallback.sol";

interface IUSUMRouter is IUSUMLiquidityCallback {
    function openPosition(
        address oracleProvider,
        address settlementToken,
        uint256 takerMargin,
        uint256 makerMargin,
        int256 qty,
        uint32 leverage,
        uint256 deadline
    ) external;

    function closePosition(
        address oracleProvider,
        address settlementToken,
        uint256 positionId,
        uint256 deadline
    ) external;

    function addLiquidity(
        address oracleProvider,
        address settlementToken,
        int16 feeRate,
        uint256 amount,
        address recipient,
        uint256 deadline
    ) external returns (uint256 liquidity);

    function removeLiquidity(
        address oracleProvider,
        address settlementToken,
        int16 feeRate,
        uint256 liquidity,
        uint256 amountMin,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amount);
}