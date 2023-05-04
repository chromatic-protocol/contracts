// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMTradeCallback} from "@usum/core/interfaces/callback/IUSUMTradeCallback.sol";
import {Position} from "@usum/core/libraries/Position.sol";

interface IAccount is IUSUMTradeCallback {
    function balance(address quote) external view returns (uint256);

    function withdraw(address quote, uint256 amount) external;

    function initialize(address _owner, address _router) external;

    // function transferMargin(
    //     uint256 marginRequired,
    //     address marketAddress,
    //     address settlementToken
    // ) intern;

    function hasPositionId(
        address marketAddress,
        uint256 positionId
    ) external view returns (bool);

    function getPositionIds(
        address marketAddress
    ) external view returns (uint256[] memory);

    function openPosition(
        address marketAddress,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external returns (Position memory);

    function closePosition(address marketAddress, uint256 positionId) external;
}
