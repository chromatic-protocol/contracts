// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {GelatoLiquidator} from "@chromatic-protocol/contracts/core/automation/GelatoLiquidator.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";

contract GelatoLiquidatorMock is GelatoLiquidator {
    constructor(
        IChromaticMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) GelatoLiquidator(_factory, _automate, opsProxyFactory) {}

    // for test
    function liquidate(address market, uint256 positionId, uint256 fee) external {
        _liquidate(market, positionId, fee);
    }
}
