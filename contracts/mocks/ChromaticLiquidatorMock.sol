// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ChromaticGelatoLiquidator} from "@chromatic-protocol/contracts/core/ChromaticGelatoLiquidator.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";

contract ChromaticLiquidatorMock is ChromaticGelatoLiquidator {
    constructor(
        IChromaticMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) ChromaticGelatoLiquidator(_factory, _automate, opsProxyFactory) {}

    function liquidate(address market, uint256 positionId, uint256 fee) external {
        _liquidate(market, positionId, fee);
    }
}
