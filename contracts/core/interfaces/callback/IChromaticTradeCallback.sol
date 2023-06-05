// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/** @title IChromatic types */
interface IChromaticTradeCallback {
    function openPositionCallback(
        address settlementToken,
        address vault,
        uint256 marginRequired,
        bytes calldata data
    ) external;

    function claimPositionCallback(uint256 positionId, bytes calldata data) external;
}
