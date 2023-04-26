// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "@usum/core/base/Liquidator.sol";
import "@usum/core/base/gelato/OpsReady.sol";
import "@usum/core/base/gelato/Types.sol";

contract USUMLiquidator is Liquidator, OpsReady {
    constructor(address _ops) OpsReady(_ops, address(this)) {}

    function getOps() internal view override returns (IOps) {
        return ops;
    }

    function liquidate(
        address market,
        uint256 positionId
    ) external override onlyDedicatedMsgSender {
        // feeToken is the native token because ETH is set as a fee token when creating task
        // TODO: need test in goerli
        (uint256 fee, ) = _getFeeDetails();

        _liquidate(market, positionId, fee);
    }
}
