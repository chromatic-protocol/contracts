// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IUSUMFactory} from "./interfaces/IUSUMFactory.sol";
import {IOracleRegistry} from "./interfaces/IOracleRegistry.sol";
import {MarketDeployer} from "./base/MarketDeployer.sol";

contract USUMFactory is IUSUMFactory, MarketDeployer {
    mapping(address => mapping(address => address)) private markets;

    IOracleRegistry public override oracleRegistry;
    address public override dao;

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
    ) external override {
        // TODO settlementToken isRegistered check
        // TODO oracleProvider isRegistered check

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
