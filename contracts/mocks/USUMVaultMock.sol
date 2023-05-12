// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {USUMVault} from "@usum/core/USUMVault.sol";
import {IAutomate, Module, ModuleData} from "@usum/core/base/gelato/Types.sol";

contract USUMVaultMock is USUMVault {
    constructor(
        IUSUMMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) USUMVault(_factory, _automate, opsProxyFactory) {}

    function distributeMakerEarning(address token, uint256 keeperFee) external {
        _distributeMakerEarning(token, keeperFee);
    }

    function distributeMarketEarning(
        address market,
        uint256 keeperFee
    ) external {
        _distributeMarketEarning(market, keeperFee);
    }

    function setPendingMarketEarnings(
        address market,
        uint256 earning
    ) external {
        pendingMarketEarnings[market] = earning;
    }

    function createMakerEarningDistributionTask(
        address token
    ) external override {
        // dummy
    }
}
