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
        address settlementToken,
        uint256 marginTransfered,
        bytes calldata data
    ) external;
}
