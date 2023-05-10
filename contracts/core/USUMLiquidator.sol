// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IUSUMLiquidator} from "@usum/core/interfaces/IUSUMLiquidator.sol";
import {Liquidator} from "@usum/core/base/Liquidator.sol";
import {AutomateReady} from "@usum/core/base/gelato/AutomateReady.sol";
import {IAutomate} from "@usum/core/base/gelato/Types.sol";

contract USUMLiquidator is Liquidator, AutomateReady {
    constructor(
        IUSUMMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    )
        Liquidator(_factory)
        AutomateReady(_automate, address(this), opsProxyFactory)
    {}

    ///@inheritdoc Liquidator
    function getAutomate() internal view override returns (IAutomate) {
        return automate;
    }

    ///@inheritdoc IUSUMLiquidator
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
