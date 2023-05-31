// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMLiquidityCallback} from "@usum/core/interfaces/callback/IUSUMLiquidityCallback.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {LpReceipt} from "@usum/core/libraries/LpReceipt.sol";

interface IUSUMRouter is IUSUMLiquidityCallback {
    function openPosition(
        address market,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external returns (Position memory);

    function closePosition(address market, uint256 positionId) external;

    function claimPosition(address market, uint256 positionId) external;

    function addLiquidity(
        address market,
        int16 feeRate,
        uint256 amount,
        address recipient
    ) external returns (LpReceipt memory);

    function claimLpToken(address market, uint256 receiptId) external;

    function removeLiquidity(
        address market,
        int16 feeRate,
        uint256 lpTokenAmount,
        uint256 amountMin,
        address recipient
    ) external returns (uint256 amount);

    function getAccount() external view returns (address);
}
