// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {GelatoLiquidator} from "@chromatic-protocol/contracts/core/automation/GelatoLiquidator.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";

contract GelatoLiquidatorMock is GelatoLiquidator {
    constructor(
        IChromaticMarketFactory _factory,
        address _automate
    ) GelatoLiquidator(_factory, _automate) {}

    // for test
    function liquidate(address market, uint256 positionId, uint256 fee) external {
        IMarketLiquidate(market).liquidate(positionId, automate.gelato(), fee);
    }
}
