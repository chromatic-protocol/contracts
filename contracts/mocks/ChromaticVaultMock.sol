// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ChromaticVault} from "@chromatic-protocol/contracts/core/ChromaticVault.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";

contract ChromaticVaultMock is ChromaticVault {
    constructor(
        IChromaticMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) ChromaticVault(_factory, _automate, opsProxyFactory) {}

    function distributeMakerEarning(address token, uint256 keeperFee) external {
        _distributeMakerEarning(token, keeperFee);
    }

    function distributeMarketEarning(address market, uint256 keeperFee) external {
        _distributeMarketEarning(market, keeperFee);
    }

    function setPendingMarketEarnings(address market, uint256 earning) external {
        pendingMarketEarnings[market] = earning;
    }

    function createMakerEarningDistributionTask(address token) external override {
        // dummy
    }

    function createMarketEarningDistributionTask(address market) external override {
        // dummy
    }
}
