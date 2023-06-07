// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarketFactory} from "@chromatic/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";
import {IMarketDeployer} from "@chromatic/core/interfaces/factory/IMarketDeployer.sol";
import {IChromaticVault} from "@chromatic/core/interfaces/IChromaticVault.sol";
import {MarketDeployer, MarketDeployerLib, Parameters} from "@chromatic/core/external/deployer/MarketDeployer.sol";
import {OracleProviderRegistry, OracleProviderRegistryLib} from "@chromatic/core/external/registry/OracleProviderRegistry.sol";
import {SettlementTokenRegistry, SettlementTokenRegistryLib} from "@chromatic/core/external/registry/SettlementTokenRegistry.sol";
import {InterestRate} from "@chromatic/core/libraries/InterestRate.sol";
import {Errors} from "@chromatic/core/libraries/Errors.sol";

contract ChromaticMarketFactory is IChromaticMarketFactory {
    using OracleProviderRegistryLib for OracleProviderRegistry;
    using SettlementTokenRegistryLib for SettlementTokenRegistry;
    using MarketDeployerLib for MarketDeployer;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public override dao;

    address public override liquidator;
    address public override vault;
    address public override keeperFeePayer;
    address public override treasury;

    OracleProviderRegistry private _oracleProviderRegistry;
    SettlementTokenRegistry private _settlementTokenRegistry;

    MarketDeployer private _deployer;
    mapping(address => mapping(address => bool)) private _registered;
    mapping(address => address[]) private _marketsBySettlementToken;
    EnumerableSet.AddressSet private _markets;

    error AlreadySetLiquidator();
    error AlreadySetVault();
    error AlreadySetKeeperFeePayer();
    error NotRegisteredOracleProvider();
    error NotRegisteredSettlementToken();
    error WrongTokenAddress();
    error ExistMarket();

    modifier onlyDao() {
        require(msg.sender == dao, Errors.ONLY_DAO_CAN_ACCESS);
        _;
    }

    constructor() {
        dao = msg.sender;
        treasury = dao;
    }

    // set DAO address
    /// @param _dao new DAO address to set
    function updateDao(address _dao) external override onlyDao {
        dao = _dao;
        emit UpdateDao(dao);
    }

    function updateTreasury(address _treasury) external override onlyDao {
        treasury = _treasury;
        emit UpdateTreasury(treasury);
    }

    function setLiquidator(address _liquidator) external override onlyDao {
        if (liquidator != address(0)) revert AlreadySetLiquidator();

        liquidator = _liquidator;
        emit SetLiquidator(liquidator);
    }

    function setVault(address _vault) external override onlyDao {
        if (vault != address(0)) revert AlreadySetVault();

        vault = _vault;
        emit SetVault(vault);
    }

    function setKeeperFeePayer(address _keeperFeePayer) external override onlyDao {
        if (keeperFeePayer != address(0)) revert AlreadySetKeeperFeePayer();

        keeperFeePayer = _keeperFeePayer;
        emit SetKeeperFeePayer(keeperFeePayer);
    }

    function getMarkets() external view override returns (address[] memory) {
        return _markets.values();
    }

    function getMarketsBySettlmentToken(
        address settlementToken
    ) external view override returns (address[] memory) {
        return _marketsBySettlementToken[settlementToken];
    }

    function getMarket(
        address oracleProvider,
        address settlementToken
    ) external view override returns (address) {
        if (!_registered[oracleProvider][settlementToken]) return address(0);

        address[] memory markets = _marketsBySettlementToken[settlementToken];
        for (uint i = 0; i < markets.length; i++) {
            if (address(IChromaticMarket(markets[i]).oracleProvider()) == oracleProvider) {
                return markets[i];
            }
        }
        return address(0);
    }

    function isRegisteredMarket(address market) external view override returns (bool) {
        return _markets.contains(market);
    }

    function createMarket(address oracleProvider, address settlementToken) external override {
        if (!_oracleProviderRegistry.isRegistered(oracleProvider))
            revert NotRegisteredOracleProvider();

        if (!_settlementTokenRegistry.isRegistered(settlementToken))
            revert NotRegisteredSettlementToken();

        if (_registered[oracleProvider][settlementToken]) revert ExistMarket();

        address market = _deployer.deploy(oracleProvider, settlementToken);

        _registered[oracleProvider][settlementToken] = true;
        _marketsBySettlementToken[settlementToken].push(market);
        _markets.add(market);

        IChromaticVault(vault).createMarketEarningDistributionTask(market);

        emit MarketCreated(oracleProvider, settlementToken, market);
    }

    ///@inheritdoc IMarketDeployer
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

    function registerOracleProvider(address oracleProvider) external override onlyDao {
        _oracleProviderRegistry.register(oracleProvider);
        emit OracleProviderRegistered(oracleProvider);
    }

    function unregisterOracleProvider(address oracleProvider) external override onlyDao {
        _oracleProviderRegistry.unregister(oracleProvider);
        emit OracleProviderUnregistered(oracleProvider);
    }

    function registeredOracleProviders() external view override returns (address[] memory) {
        return _oracleProviderRegistry.oracleProviders();
    }

    function isRegisteredOracleProvider(
        address oracleProvider
    ) external view override returns (bool) {
        return _oracleProviderRegistry.isRegistered(oracleProvider);
    }

    // implement ISettlementTokenRegistry

    function registerSettlementToken(
        address token,
        uint256 minimumTakerMargin,
        uint256 interestRate,
        uint256 flashLoanFeeRate,
        uint256 earningDistributionThreshold,
        uint24 uniswapFeeTier
    ) external override onlyDao {
        _settlementTokenRegistry.register(
            token,
            minimumTakerMargin,
            interestRate,
            flashLoanFeeRate,
            earningDistributionThreshold,
            uniswapFeeTier
        );

        IChromaticVault(vault).createMakerEarningDistributionTask(token);

        emit SettlementTokenRegistered(
            token,
            minimumTakerMargin,
            interestRate,
            flashLoanFeeRate,
            earningDistributionThreshold,
            uniswapFeeTier
        );
    }

    function registeredSettlementTokens() external view override returns (address[] memory) {
        return _settlementTokenRegistry.settlementTokens();
    }

    function isRegisteredSettlementToken(address token) external view override returns (bool) {
        return _settlementTokenRegistry.isRegistered(token);
    }

    function getMinimumTakerMargin(address token) external view returns (uint256) {
        return _settlementTokenRegistry.getMinimumTakerMargin(token);
    }

    function setMinimumTakerMargin(address token, uint256 minimumTakerMargin) external onlyDao {
        _settlementTokenRegistry.setMinimumTakerMargin(token, minimumTakerMargin);
        emit SetMinimumTakerMargin(token, minimumTakerMargin);
    }

    function getFlashLoanFeeRate(address token) external view returns (uint256) {
        return _settlementTokenRegistry.getFlashLoanFeeRate(token);
    }

    function setFlashLoanFeeRate(address token, uint256 flashLoanFeeRate) external onlyDao {
        _settlementTokenRegistry.setFlashLoanFeeRate(token, flashLoanFeeRate);
        emit SetFlashLoanFeeRate(token, flashLoanFeeRate);
    }

    function getEarningDistributionThreshold(address token) external view returns (uint256) {
        return _settlementTokenRegistry.getEarningDistributionThreshold(token);
    }

    function setEarningDistributionThreshold(
        address token,
        uint256 earningDistributionThreshold
    ) external onlyDao {
        _settlementTokenRegistry.setEarningDistributionThreshold(
            token,
            earningDistributionThreshold
        );
        emit SetEarningDistributionThreshold(token, earningDistributionThreshold);
    }

    function getUniswapFeeTier(address token) external view returns (uint24) {
        return _settlementTokenRegistry.getUniswapFeeTier(token);
    }

    function setUniswapFeeTier(address token, uint24 uniswapFeeTier) external onlyDao {
        _settlementTokenRegistry.setUniswapFeeTier(token, uniswapFeeTier);
        emit SetUniswapFeeTier(token, uniswapFeeTier);
    }

    function appendInterestRateRecord(
        address token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) external override onlyDao {
        _settlementTokenRegistry.appendInterestRateRecord(token, annualRateBPS, beginTimestamp);
        emit InterestRateRecordAppended(token, annualRateBPS, beginTimestamp);
    }

    function removeLastInterestRateRecord(address token) external override onlyDao {
        (bool removed, InterestRate.Record memory record) = _settlementTokenRegistry
            .removeLastInterestRateRecord(token);

        if (removed) {
            emit LastInterestRateRecordRemoved(token, record.annualRateBPS, record.beginTimestamp);
        }
    }

    function getInterestRateRecords(
        address token
    ) external view returns (InterestRate.Record[] memory) {
        return _settlementTokenRegistry.getInterestRateRecords(token);
    }

    function currentInterestRate(
        address token
    ) external view override returns (uint256 annualRateBPS) {
        return _settlementTokenRegistry.currentInterestRate(token);
    }

    // implement IInterestCalculator

    function calculateInterest(
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to // timestamp (exclusive)
    ) external view override returns (uint256) {
        return _settlementTokenRegistry.calculateInterest(token, amount, from, to);
    }

    // manage vault automate

    function createMakerEarningDistributionTask(address token) external override onlyDao {
        IChromaticVault(vault).createMakerEarningDistributionTask(token);
    }

    function cancelMakerEarningDistributionTask(address token) external override onlyDao {
        IChromaticVault(vault).cancelMakerEarningDistributionTask(token);
    }

    function createMarketEarningDistributionTask(address market) external override onlyDao {
        IChromaticVault(vault).createMarketEarningDistributionTask(market);
    }

    function cancelMarketEarningDistributionTask(address market) external override onlyDao {
        IChromaticVault(vault).cancelMarketEarningDistributionTask(market);
    }
}
