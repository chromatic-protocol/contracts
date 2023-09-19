// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ChromaticMate2Liquidator} from "@chromatic-protocol/contracts/core/ChromaticMate2Liquidator.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";

contract ChromaticMate2LiquidatorMock is ChromaticMate2Liquidator {
    constructor(
        IChromaticMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) ChromaticMate2Liquidator(_factory, _automate) {}
}
