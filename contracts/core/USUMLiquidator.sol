// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "@usum/core/base/Liquidator.sol";
import "@usum/core/base/gelato/AutomateReady.sol";
import "@usum/core/base/gelato/Types.sol";

contract USUMLiquidator is Liquidator, AutomateReady {
    constructor(address _automate) AutomateReady(_automate, address(this)) {}

    function getAutomate() internal view override returns (IAutomate) {
        return automate;
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
