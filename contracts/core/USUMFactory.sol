// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IUSUMFactory} from "@usum/core/interfaces/IUSUMFactory.sol";
import {IOracleRegistry} from "@usum/core/interfaces/IOracleRegistry.sol";
import {MarketDeployer} from "@usum/core/base/MarketDeployer.sol";
import {SettlementTokenRegistry} from "@usum/core/base/SettlementTokenRegistry.sol";

contract USUMFactory is IUSUMFactory, MarketDeployer, SettlementTokenRegistry {
    mapping(address => mapping(address => address)) private markets;

    IOracleRegistry public override oracleRegistry;

    error NotRegisteredOracle();
    error WrongTokenAddress();
    error ExistMarket();

    constructor(address _oracleRegistry) {
        oracleRegistry = IOracleRegistry(_oracleRegistry);
    }

    function getMarket(
        address oracleProvider,
        address settlementToken
    ) external view override returns (address market) {
        market = markets[oracleProvider][settlementToken];
    }

    function createMarket(
        address oracleProvider,
        address settlementToken
    ) external override registeredOnly(settlementToken) {
        if (
            oracleProvider == address(0) ||
            !oracleRegistry.isRegistered(oracleProvider)
        ) revert NotRegisteredOracle();

        if (settlementToken == address(0) || settlementToken == oracleProvider)
            revert WrongTokenAddress();

        if (markets[oracleProvider][settlementToken] != address(0))
            revert ExistMarket();

        address market = deploy(oracleProvider, settlementToken);

        markets[oracleProvider][settlementToken] = market;

        emit MarketCreated(oracleProvider, settlementToken, market);
    }
}
