// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {USUMLiquidator} from "@usum/core/USUMLiquidator.sol";
import {IAutomate, Module, ModuleData} from "@usum/core/base/gelato/Types.sol";

contract USUMLiquidatorMock is USUMLiquidator {
    constructor(address _automate) USUMLiquidator(_automate) {}

    function liquidate(
        address market,
        uint256 positionId,
        uint256 fee
    ) external {
        _liquidate(market, positionId, fee);
    }
}
