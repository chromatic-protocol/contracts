// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IOracleRegistry} from "@usum/core/interfaces/IOracleRegistry.sol";
import {SettlementTokenRegistry} from "@usum/core/base/factory/SettlementTokenRegistry.sol";
import {MarketDeployer, MarketDeployerLib, Parameters} from "@usum/core/external/deployer/MarketDeployer.sol";

contract USUMMarketFactory is SettlementTokenRegistry {
    using MarketDeployerLib for MarketDeployer;

    IOracleRegistry public override oracleRegistry;
    address public immutable override liquidator;
    address public immutable override keeperFeePayer;

    MarketDeployer _deployer;
    mapping(address => mapping(address => address)) private _markets;

    error NotRegisteredOracle();
    error WrongTokenAddress();
    error ExistMarket();

    constructor(
        address _oracleRegistry,
        address _liquidator,
        address _keeperFeePayer
    ) {
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        liquidator = _liquidator;
        keeperFeePayer = _keeperFeePayer;
    }

    function getMarket(
        address oracleProvider,
        address settlementToken
    ) external view override returns (address market) {
        market = _markets[oracleProvider][settlementToken];
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

        if (_markets[oracleProvider][settlementToken] != address(0))
            revert ExistMarket();

        address market = _deployer.deploy(oracleProvider, settlementToken);

        _markets[oracleProvider][settlementToken] = market;

        emit MarketCreated(oracleProvider, settlementToken, market);
    }

    function parameters()
        external
        view
        override
        returns (address oracleProvider, address settlementToken)
    {
        Parameters memory params = _deployer.parameters;
        return (params.oracleProvider, params.settlementToken);
    }
}
