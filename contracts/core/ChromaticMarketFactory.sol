// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IInterestCalculator} from "@chromatic-protocol/contracts/core/interfaces/IInterestCalculator.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IMarketDeployer} from "@chromatic-protocol/contracts/core/interfaces/factory/IMarketDeployer.sol";
import {IOracleProviderRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/IOracleProviderRegistry.sol";
import {ISettlementTokenRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/ISettlementTokenRegistry.sol";
import {MarketDeployer, MarketDeployerLib, Parameters} from "@chromatic-protocol/contracts/core/external/deployer/MarketDeployer.sol";
import {OracleProviderRegistry, OracleProviderRegistryLib} from "@chromatic-protocol/contracts/core/external/registry/OracleProviderRegistry.sol";
import {SettlementTokenRegistry, SettlementTokenRegistryLib} from "@chromatic-protocol/contracts/core/external/registry/SettlementTokenRegistry.sol";
import {InterestRate} from "@chromatic-protocol/contracts/core/libraries/InterestRate.sol";
import {Errors} from "@chromatic-protocol/contracts/core/libraries/Errors.sol";

/**
 * @title ChromaticMarketFactory
 * @dev Contract for managing the creation and registration of Chromatic markets.
 */
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

    /**
     * @dev Modifier to restrict access to only the DAO address
     */
    modifier onlyDao() {
        require(msg.sender == dao, Errors.ONLY_DAO_CAN_ACCESS);
        _;
    }

    /**
     * @dev Modifier to ensure that the caller is a registered oracle provider.
     *      Throws a 'NotRegisteredOracleProvider' error if the oracle provider is not registered.
     * @param oracleProvider The address of the oracle provider.
     */
    modifier onlyRegisteredOracleProvider(address oracleProvider) {
        if (!_oracleProviderRegistry.isRegistered(oracleProvider))
            revert NotRegisteredOracleProvider();
        _;
    }

    /**
     * @dev Initializes the ChromaticMarketFactory contract.
     */
    constructor() {
        dao = msg.sender;
        treasury = dao;
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateDao(address _dao) external override onlyDao {
        dao = _dao;
        emit UpdateDao(dao);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateTreasury(address _treasury) external override onlyDao {
        treasury = _treasury;
        emit UpdateTreasury(treasury);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function setLiquidator(address _liquidator) external override onlyDao {
        if (liquidator != address(0)) revert AlreadySetLiquidator();

        liquidator = _liquidator;
        emit SetLiquidator(liquidator);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function setVault(address _vault) external override onlyDao {
        if (vault != address(0)) revert AlreadySetVault();

        vault = _vault;
        emit SetVault(vault);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function setKeeperFeePayer(address _keeperFeePayer) external override onlyDao {
        if (keeperFeePayer != address(0)) revert AlreadySetKeeperFeePayer();

        keeperFeePayer = _keeperFeePayer;
        emit SetKeeperFeePayer(keeperFeePayer);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     */
    function getMarkets() external view override returns (address[] memory) {
        return _markets.values();
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     */
    function getMarketsBySettlmentToken(
        address settlementToken
    ) external view override returns (address[] memory) {
        return _marketsBySettlementToken[settlementToken];
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     */
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

    /**
     * @inheritdoc IChromaticMarketFactory
     */
    function isRegisteredMarket(address market) external view override returns (bool) {
        return _markets.contains(market);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     */
    function createMarket(
        address oracleProvider,
        address settlementToken
    ) external override onlyRegisteredOracleProvider(oracleProvider) {
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

    /**
     * @inheritdoc IMarketDeployer
     */
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

    /**
     * @inheritdoc IOracleProviderRegistry
     * @dev This function can only be called by the DAO address.
     */
    function registerOracleProvider(address oracleProvider) external override onlyDao {
        _oracleProviderRegistry.register(oracleProvider);
        emit OracleProviderRegistered(oracleProvider);
    }

    /**
     * @inheritdoc IOracleProviderRegistry
     * @dev This function can only be called by the DAO address.
     */
    function unregisterOracleProvider(address oracleProvider) external override onlyDao {
        _oracleProviderRegistry.unregister(oracleProvider);
        emit OracleProviderUnregistered(oracleProvider);
    }

    /**
     * @inheritdoc IOracleProviderRegistry
     */
    function registeredOracleProviders() external view override returns (address[] memory) {
        return _oracleProviderRegistry.oracleProviders();
    }

    /**
     * @inheritdoc IOracleProviderRegistry
     */
    function isRegisteredOracleProvider(
        address oracleProvider
    ) external view override returns (bool) {
        return _oracleProviderRegistry.isRegistered(oracleProvider);
    }

    /**
     * @inheritdoc IOracleProviderRegistry
     */
    function getOracleProviderLevel(
        address oracleProvider
    ) external view override onlyRegisteredOracleProvider(oracleProvider) returns (uint8) {
        return _oracleProviderRegistry.getOracleProviderLevel(oracleProvider);
    }

    /**
     * @inheritdoc IOracleProviderRegistry
     * @dev This function can only be called by the DAO and registered oracle providers.
     */
    function setOracleProviderLevel(
        address oracleProvider,
        uint8 level
    ) external override onlyDao onlyRegisteredOracleProvider(oracleProvider) {
        require(level <= 1);
        _oracleProviderRegistry.setOracleProviderLevel(oracleProvider, level);
        emit SetOracleProviderLevel(oracleProvider, level);
    }

    // implement ISettlementTokenRegistry

    /**
     * @inheritdoc ISettlementTokenRegistry
     * @dev This function can only be called by the DAO address.
     */
    function registerSettlementToken(
        address token,
        uint256 minimumMargin,
        uint256 interestRate,
        uint256 flashLoanFeeRate,
        uint256 earningDistributionThreshold,
        uint24 uniswapFeeTier
    ) external override onlyDao {
        _settlementTokenRegistry.register(
            token,
            minimumMargin,
            interestRate,
            flashLoanFeeRate,
            earningDistributionThreshold,
            uniswapFeeTier
        );

        IChromaticVault(vault).createMakerEarningDistributionTask(token);

        emit SettlementTokenRegistered(
            token,
            minimumMargin,
            interestRate,
            flashLoanFeeRate,
            earningDistributionThreshold,
            uniswapFeeTier
        );
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     */
    function registeredSettlementTokens() external view override returns (address[] memory) {
        return _settlementTokenRegistry.settlementTokens();
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     */
    function isRegisteredSettlementToken(address token) external view override returns (bool) {
        return _settlementTokenRegistry.isRegistered(token);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     */
    function getMinimumMargin(address token) external view returns (uint256) {
        return _settlementTokenRegistry.getMinimumMargin(token);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     * @dev This function can only be called by the DAO address.
     */
    function setMinimumMargin(address token, uint256 minimumMargin) external onlyDao {
        _settlementTokenRegistry.setMinimumMargin(token, minimumMargin);
        emit SetMinimumMargin(token, minimumMargin);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     */
    function getFlashLoanFeeRate(address token) external view returns (uint256) {
        return _settlementTokenRegistry.getFlashLoanFeeRate(token);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     * @dev This function can only be called by the DAO address.
     */
    function setFlashLoanFeeRate(address token, uint256 flashLoanFeeRate) external onlyDao {
        _settlementTokenRegistry.setFlashLoanFeeRate(token, flashLoanFeeRate);
        emit SetFlashLoanFeeRate(token, flashLoanFeeRate);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     */
    function getEarningDistributionThreshold(address token) external view returns (uint256) {
        return _settlementTokenRegistry.getEarningDistributionThreshold(token);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     * @dev This function can only be called by the DAO address.
     */
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

    /**
     * @inheritdoc ISettlementTokenRegistry
     */
    function getUniswapFeeTier(address token) external view returns (uint24) {
        return _settlementTokenRegistry.getUniswapFeeTier(token);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     * @dev This function can only be called by the DAO address.
     */
    function setUniswapFeeTier(address token, uint24 uniswapFeeTier) external onlyDao {
        _settlementTokenRegistry.setUniswapFeeTier(token, uniswapFeeTier);
        emit SetUniswapFeeTier(token, uniswapFeeTier);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     * @dev This function can only be called by the DAO address.
     */
    function appendInterestRateRecord(
        address token,
        uint256 annualRateBPS,
        uint256 beginTimestamp
    ) external override onlyDao {
        _settlementTokenRegistry.appendInterestRateRecord(token, annualRateBPS, beginTimestamp);
        emit InterestRateRecordAppended(token, annualRateBPS, beginTimestamp);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     * @dev This function can only be called by the DAO address.
     */
    function removeLastInterestRateRecord(address token) external override onlyDao {
        (bool removed, InterestRate.Record memory record) = _settlementTokenRegistry
            .removeLastInterestRateRecord(token);

        if (removed) {
            emit LastInterestRateRecordRemoved(token, record.annualRateBPS, record.beginTimestamp);
        }
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     */
    function getInterestRateRecords(
        address token
    ) external view returns (InterestRate.Record[] memory) {
        return _settlementTokenRegistry.getInterestRateRecords(token);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     */
    function currentInterestRate(
        address token
    ) external view override returns (uint256 annualRateBPS) {
        return _settlementTokenRegistry.currentInterestRate(token);
    }

    // implement IInterestCalculator

    /**
     * @inheritdoc IInterestCalculator
     */
    function calculateInterest(
        address token,
        uint256 amount,
        uint256 from, // timestamp (inclusive)
        uint256 to // timestamp (exclusive)
    ) external view override returns (uint256) {
        return _settlementTokenRegistry.calculateInterest(token, amount, from, to);
    }

    // manage vault automate

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function createMakerEarningDistributionTask(address token) external override onlyDao {
        IChromaticVault(vault).createMakerEarningDistributionTask(token);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function cancelMakerEarningDistributionTask(address token) external override onlyDao {
        IChromaticVault(vault).cancelMakerEarningDistributionTask(token);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function createMarketEarningDistributionTask(address market) external override onlyDao {
        IChromaticVault(vault).createMarketEarningDistributionTask(market);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function cancelMarketEarningDistributionTask(address market) external override onlyDao {
        IChromaticVault(vault).cancelMarketEarningDistributionTask(market);
    }
}
