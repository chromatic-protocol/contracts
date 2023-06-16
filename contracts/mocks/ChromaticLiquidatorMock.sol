// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ChromaticLiquidator} from "@chromatic-protocol/contracts/core/ChromaticLiquidator.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";

contract ChromaticLiquidatorMock is ChromaticLiquidator {
    constructor(
        IChromaticMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) ChromaticLiquidator(_factory, _automate, opsProxyFactory) {}

    function liquidate(address market, uint256 positionId, uint256 fee) external {
        _liquidate(market, positionId, fee);
    }
}
