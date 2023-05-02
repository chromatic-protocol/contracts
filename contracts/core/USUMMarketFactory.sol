// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {InterestRate} from "@usum/core/libraries/InterestRate.sol";
import {MarketDeployer, MarketDeployerLib, Parameters} from "@usum/core/external/deployer/MarketDeployer.sol";
import {OracleProviderRegistry, OracleProviderRegistryLib} from "@usum/core/external/registry/OracleProviderRegistry.sol";
import {SettlementTokenRegistry, SettlementTokenRegistryLib} from "@usum/core/external/registry/SettlementTokenRegistry.sol";

contract USUMMarketFactory is IUSUMMarketFactory {
    using OracleProviderRegistryLib for OracleProviderRegistry;
    using SettlementTokenRegistryLib for SettlementTokenRegistry;
    using MarketDeployerLib for MarketDeployer;

    address public override dao;

    address public immutable override liquidator;
    address public immutable override keeperFeePayer;

    OracleProviderRegistry private _oracleProviderRegistry;
    SettlementTokenRegistry private _settlementTokenRegistry;

    MarketDeployer private _deployer;
    mapping(address => mapping(address => address)) private _markets;

    error NotRegisteredOracleProvider();
    error NotRegisteredSettlementToken();
    error WrongTokenAddress();
    error ExistMarket();

    modifier onlyDao() {
        require(msg.sender == dao, "only DAO can access");
        _;
    }

    constructor(address _liquidator, address _keeperFeePayer) {
        dao = msg.sender;
        liquidator = _liquidator;
        keeperFeePayer = _keeperFeePayer;
    }

    function updateDao(address _dao) external onlyDao {
        dao = _dao;
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
    ) external override {
        if (!_oracleProviderRegistry.isRegistered(oracleProvider))
            revert NotRegisteredOracleProvider();

        if (!_settlementTokenRegistry.isRegistered(settlementToken))
            revert NotRegisteredSettlementToken();

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

    // implement IOracleProviderRegistry

    function registerOracleProvider(
        address oracleProvider
    ) external override onlyDao {
        _oracleProviderRegistry.register(oracleProvider);
        emit OracleProviderRegistered(oracleProvider);
    }

    function unregisterOracleProvider(
        address oracleProvider
    ) external override onlyDao {
        _oracleProviderRegistry.unregister(oracleProvider);
        emit OracleProviderUnregistered(oracleProvider);
    }

    function registeredOracleProviders()
        external
        view
        override
        returns (address[] memory)
    {
        return _oracleProviderRegistry.oracleProviders();
    }

    function isRegisteredOracleProvider(
        address oracleProvider
    ) external view override returns (bool) {
        return _oracleProviderRegistry.isRegistered(oracleProvider);
    }

    // implement ISettlementTokenRegistry

    function registerSettlementToken(address token) external override onlyDao {
        _settlementTokenRegistry.register(token);
        emit SettlementTokenRegistered(token);
    }

    function registeredSettlementTokens()
        external
        view
        override
        returns (address[] memory)
    {
        return _settlementTokenRegistry.settlmentTokens();
    }

    function isRegisteredSettlementToken(
        address token
    ) external view override returns (bool) {
        return _settlementTokenRegistry.isRegistered(token);
    }

    function appendInterestRateRecord(
        address token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) external override onlyDao {
        _settlementTokenRegistry.appendInterestRateRecord(
            token,
            annualRateBPS,
            beginTimestamp
        );
        emit InterestRateRecordAppended(token, annualRateBPS, beginTimestamp);
    }

    function removeLastInterestRateRecord(
        address token
    ) external override onlyDao {
        (
            bool removed,
            InterestRate.Record memory record
        ) = _settlementTokenRegistry.removeLastInterestRateRecord(token);

        if (removed) {
            emit LastInterestRateRecordRemoved(
                token,
                record.annualRateBPS,
                record.beginTimestamp
            );
        }
    }

    function currentInterestRate(
        address token
    ) external view override returns (uint256 annualRateBPS) {
        return _settlementTokenRegistry.currentInterestRate(token);
    }

    function calculateInterest(
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to // timestamp (exclusive)
    ) external view override returns (uint256) {
        return
            _settlementTokenRegistry.calculateInterest(
                token,
                amount,
                from,
                to,
                Math.Rounding.Down
            );
    }

    function calculateInterest(
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to, // timestamp (exclusive)
        Math.Rounding rounding
    ) external view override returns (uint256) {
        return
            _settlementTokenRegistry.calculateInterest(
                token,
                amount,
                from,
                to,
                rounding
            );
    }
}
