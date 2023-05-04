// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/** @title IUSUM types */
interface IUSUMTradeCallback {
    function openPositionCallback(
        address settlementToken,
        uint256 marginRequired,
        bytes calldata data
    ) external;

    function closePositionCallback(
        uint256 positionId,
        bytes calldata data
    ) external;
}
