// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticLiquidator} from "@chromatic/core/interfaces/IChromaticLiquidator.sol";
import {Liquidator} from "@chromatic/core/base/Liquidator.sol";
import {AutomateReady} from "@chromatic/core/base/gelato/AutomateReady.sol";
import {IAutomate} from "@chromatic/core/base/gelato/Types.sol";

contract ChromaticLiquidator is Liquidator, AutomateReady {
    constructor(
        IChromaticMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) Liquidator(_factory) AutomateReady(_automate, address(this), opsProxyFactory) {}

    ///@inheritdoc Liquidator
    function getAutomate() internal view override returns (IAutomate) {
        return automate;
    }

    ///@inheritdoc IChromaticLiquidator
    function liquidate(
        address market,
        uint256 positionId
    ) external override onlyDedicatedMsgSender {
        // feeToken is the native token because ETH is set as a fee token when creating task
        // TODO: need test in goerli
        (uint256 fee, ) = _getFeeDetails();
        _liquidate(market, positionId, fee);
    }

    ///@inheritdoc IChromaticLiquidator
    function claimPosition(
        address market,
        uint256 positionId
    ) external override onlyDedicatedMsgSender {
        // feeToken is the native token because ETH is set as a fee token when creating task
        (uint256 fee, ) = _getFeeDetails();
        _claimPosition(market, positionId, fee);
    }
}
