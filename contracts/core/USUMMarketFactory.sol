// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {SettlementTokenRegistry} from "@usum/core/base/factory/SettlementTokenRegistry.sol";
import {MarketDeployer, MarketDeployerLib, Parameters} from "@usum/core/external/deployer/MarketDeployer.sol";
import {OracleRegistry, OracleRegistryLib} from "@usum/core/external/registry/OracleRegistry.sol";

contract USUMMarketFactory is IUSUMMarketFactory, SettlementTokenRegistry {
    using OracleRegistryLib for OracleRegistry;
    using MarketDeployerLib for MarketDeployer;

    address public immutable override liquidator;
    address public immutable override keeperFeePayer;

    OracleRegistry private _oracleRegistry;

    MarketDeployer private _deployer;
    mapping(address => mapping(address => address)) private _markets;

    error NotRegisteredOracleProvider();
    error WrongTokenAddress();
    error ExistMarket();

    constructor(address _liquidator, address _keeperFeePayer) {
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
            !_oracleRegistry.isRegistered(oracleProvider)
        ) revert NotRegisteredOracleProvider();

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

    // implement IOracleRegistry

    function registerOracleProvider(
        address oracleProvider
    ) external override onlyDao {
        _oracleRegistry.register(oracleProvider);
        emit OracleProviderRegistered(oracleProvider);
    }

    function unregisterOracleProvider(
        address oracleProvider
    ) external override onlyDao {
        _oracleRegistry.unregister(oracleProvider);
        emit OracleProviderUnregistered(oracleProvider);
    }

    function isRegisteredOracleProvider(
        address oracleProvider
    ) external view override returns (bool) {
        return _oracleRegistry.isRegistered(oracleProvider);
    }
}
