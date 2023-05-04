// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Liquidator} from "@usum/core/base/Liquidator.sol";
import {AutomateReady} from "@usum/core/base/gelato/AutomateReady.sol";
import {IAutomate} from "@usum/core/base/gelato/Types.sol";
import 'hardhat/console.sol';
contract USUMLiquidator is Liquidator, AutomateReady {
    constructor(address _automate, address opsProxyFactory) AutomateReady(_automate, address(this), opsProxyFactory ) {}

    function getAutomate() internal view override returns (IAutomate) {
        return automate;
    }

    function liquidate(
        address market,
        uint256 positionId
    ) external override onlyDedicatedMsgSender {
        // feeToken is the native token because ETH is set as a fee token when creating task
        // TODO: need test in goerli
        console.log('call liquidate');
    
        (uint256 fee, ) = _getFeeDetails();

        _liquidate(market, positionId, fee);
    }
}
