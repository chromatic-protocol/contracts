// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {Mate2Liquidator} from "@chromatic-protocol/contracts/core/automation/Mate2Liquidator.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";

contract Mate2LiquidatorMock is Mate2Liquidator {
    constructor(
        IChromaticMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) Mate2Liquidator(_factory, _automate) {}
}
