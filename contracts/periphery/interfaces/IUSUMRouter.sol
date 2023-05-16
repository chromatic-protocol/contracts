// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMLiquidityCallback} from "@usum/core/interfaces/callback/IUSUMLiquidityCallback.sol";
import {Position} from "@usum/core/libraries/Position.sol";

interface IUSUMRouter is IUSUMLiquidityCallback {
    function openPosition(
        address market,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        uint256 deadline
    ) external returns (Position memory);

    function closePosition(
        address market,
        uint256 positionId,
        uint256 deadline
    ) external;

    function addLiquidity(
        address market,
        int16 feeRate,
        uint256 amount,
        address recipient,
        uint256 deadline
    ) external returns (uint256 liquidity);

    function removeLiquidity(
        address market,
        int16 feeRate,
        uint256 liquidity,
        uint256 amountMin,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amount);

    function getAccount() external view returns (address);
}
