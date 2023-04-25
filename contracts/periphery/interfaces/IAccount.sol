// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IUSUMTradeCallback} from "@usum/core/interfaces/callback/IUSUMTradeCallback.sol";

interface IAccount is IUSUMTradeCallback {
    function balance(address quote) external view returns (uint256);

    function withdraw(address quote, uint256 amount) external;

    function initialize(address _owner, address _router) external;

    function transferMargin(
        uint256 marginRequired,
        address marketAddress,
        address settlementToken
    ) external;

    function hasPositionId(uint256) external returns (bool);

    function getPositionIds() external returns (uint256[] memory);

    function openPosition(
        address marketAddress,
        int256 quantity,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin
    ) external;

    function closePosition(address marketAddress, uint256 positionId) external;
}