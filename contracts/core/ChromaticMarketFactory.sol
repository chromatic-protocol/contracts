// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IInterestCalculator} from "@chromatic-protocol/contracts/core/interfaces/IInterestCalculator.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
import {IMarketDeployer} from "@chromatic-protocol/contracts/core/interfaces/factory/IMarketDeployer.sol";
import {IOracleProviderRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/IOracleProviderRegistry.sol";
import {ISettlementTokenRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/ISettlementTokenRegistry.sol";
import {IMarketState} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketState.sol";
import {OracleProviderRegistry, OracleProviderRegistryLib} from "@chromatic-protocol/contracts/core/libraries/registry/OracleProviderRegistry.sol";
import {SettlementTokenRegistry, SettlementTokenRegistryLib} from "@chromatic-protocol/contracts/core/libraries/registry/SettlementTokenRegistry.sol";
import {InterestRate} from "@chromatic-protocol/contracts/core/libraries/InterestRate.sol";
import {MarketDeployer, MarketDeployerLib, Parameters} from "@chromatic-protocol/contracts/core/libraries/deployer/MarketDeployer.sol";

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

    address private immutable marketDiamondCutFacet;
    address private immutable marketLoupeFacet;
    address private immutable marketStateFacet;
    address private immutable marketLiquidityFacet;
    address private immutable marketTradeFacet;
    address private immutable marketLiquidateFacet;
    address private immutable marketSettleFacet;

    OracleProviderRegistry private _oracleProviderRegistry;
    SettlementTokenRegistry private _settlementTokenRegistry;

    MarketDeployer private _deployer;
    mapping(address => mapping(address => bool)) private _registered;
    mapping(address => address[]) private _marketsBySettlementToken;
    EnumerableSet.AddressSet private _markets;

    /**
     * @dev Throws an error indicating that the caller is not the DAO.
     */
    error OnlyAccessableByDao();

    /**
     * @dev Throws an error indicating that the chromatic liquidator address is already set.
     */
    error AlreadySetLiquidator();

    /**
     * @dev Throws an error indicating that the chromatic vault address is already set.
     */
    error AlreadySetVault();

    /**
     * @dev Throws an error indicating that the keeper fee payer address is already set.
     */
    error AlreadySetKeeperFeePayer();

    /**
     * @dev Throws an error indicating that the oracle provider is not registered.
     */
    error NotRegisteredOracleProvider();

    /**
     * @dev Throws an error indicating that the settlement token is not registered.
     */
    error NotRegisteredSettlementToken();

    /**
     * @dev Throws an error indicating that a market already exists for the given oracle provider and settlement token.
     */
    error ExistMarket();

    /**
     * @dev Modifier to restrict access to only the DAO address
     *      Throws an `OnlyAccessableByDao` error if the caller is not the DAO.
     */
    modifier onlyDao() {
        if (msg.sender != dao) revert OnlyAccessableByDao();
        _;
    }

    /**
     * @dev Modifier to ensure that the specified oracle provider is registered.
     *      Throws a `NotRegisteredOracleProvider` error if the oracle provider is not registered.
     *
     * @param oracleProvider The address of the oracle provider to check.
     *
     * Requirements:
     * - The `oracleProvider` address must be registered in the `_oracleProviderRegistry`.
     */
    modifier onlyRegisteredOracleProvider(address oracleProvider) {
        if (!_oracleProviderRegistry.isRegistered(oracleProvider))
            revert NotRegisteredOracleProvider();
        _;
    }

    /**
     * @dev Initializes the ChromaticMarketFactory contract.
     * @param _marketDiamondCutFacet The market diamond cut facet address.
     * @param _marketLoupeFacet The market loupe facet address.
     * @param _marketStateFacet The market state facet address.
     * @param _marketLiquidityFacet The market liquidity facet address.
     * @param _marketTradeFacet The market trade facet address.
     * @param _marketLiquidateFacet The market liquidate facet address.
     * @param _marketSettleFacet The market settle facet address.
     */
    constructor(
        address _marketDiamondCutFacet,
        address _marketLoupeFacet,
        address _marketStateFacet,
        address _marketLiquidityFacet,
        address _marketTradeFacet,
        address _marketLiquidateFacet,
        address _marketSettleFacet
    ) {
        require(_marketDiamondCutFacet != address(0));
        require(_marketLoupeFacet != address(0));
        require(_marketStateFacet != address(0));
        require(_marketLiquidityFacet != address(0));
        require(_marketTradeFacet != address(0));
        require(_marketLiquidateFacet != address(0));
        require(_marketSettleFacet != address(0));

        dao = msg.sender;
        treasury = dao;

        marketDiamondCutFacet = _marketDiamondCutFacet;
        marketLoupeFacet = _marketLoupeFacet;
        marketStateFacet = _marketStateFacet;
        marketLiquidityFacet = _marketLiquidityFacet;
        marketTradeFacet = _marketTradeFacet;
        marketLiquidateFacet = _marketLiquidateFacet;
        marketSettleFacet = _marketSettleFacet;
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateDao(address _dao) external override onlyDao {
        require(_dao != address(0));
        dao = _dao;
        emit UpdateDao(dao);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateTreasury(address _treasury) external override onlyDao {
        require(_treasury != address(0));
        treasury = _treasury;
        emit UpdateTreasury(treasury);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     *      Throws an `AlreadySetLiquidator` error if the liquidator address has already been set.
     */
    function setLiquidator(address _liquidator) external override onlyDao {
        require(_liquidator != address(0));
        if (liquidator != address(0)) revert AlreadySetLiquidator();

        liquidator = _liquidator;
        emit SetLiquidator(liquidator);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     *      Throws an `AlreadySetVault` error if the vault address has already been set.
     */
    function setVault(address _vault) external override onlyDao {
        require(_vault != address(0));
        if (vault != address(0)) revert AlreadySetVault();

        vault = _vault;
        emit SetVault(vault);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     *      Throws an `AlreadySetKeeperFeePayer` error if the keeper fee payer address has already been set.
     */
    function setKeeperFeePayer(address _keeperFeePayer) external override onlyDao {
        require(_keeperFeePayer != address(0));
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
        for (uint i; i < markets.length; ) {
            //slither-disable-next-line calls-loop
            if (address(IMarketState(markets[i]).oracleProvider()) == oracleProvider) {
                return markets[i];
            }

            unchecked {
                i++;
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
     * @dev This function creates a new market using the specified oracle provider and settlement token addresses.
     *      Throws a `NotRegisteredSettlementToken` error if the settlement token is not registered.
     *      Throws an `ExistMarket` error if the market already exists for the given oracle provider and settlement token.
     */
    function createMarket(
        address oracleProvider,
        address settlementToken
    ) external override onlyRegisteredOracleProvider(oracleProvider) {
        if (!_settlementTokenRegistry.isRegistered(settlementToken))
            revert NotRegisteredSettlementToken();

        if (_registered[oracleProvider][settlementToken]) revert ExistMarket();
        _registered[oracleProvider][settlementToken] = true;

        address market = _deployer.deploy(
            oracleProvider,
            settlementToken,
            marketDiamondCutFacet,
            marketLoupeFacet,
            marketStateFacet,
            marketLiquidityFacet,
            marketTradeFacet,
            marketLiquidateFacet,
            marketSettleFacet
        );

        //slither-disable-next-line reentrancy-benign
        _marketsBySettlementToken[settlementToken].push(market);
        //slither-disable-next-line unused-return
        _markets.add(market);

        //slither-disable-next-line reentrancy-events
        emit MarketCreated(oracleProvider, settlementToken, market);

        IChromaticVault(vault).createMarketEarningDistributionTask(market);
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
    function registerOracleProvider(
        address oracleProvider,
        OracleProviderProperties memory properties
    ) external override onlyDao {
        _oracleProviderRegistry.register(
            oracleProvider,
            properties.minTakeProfitBPS,
            properties.maxTakeProfitBPS,
            properties.leverageLevel
        );
        emit OracleProviderRegistered(oracleProvider, properties);
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
    function getOracleProviderProperties(
        address oracleProvider
    )
        external
        view
        override
        onlyRegisteredOracleProvider(oracleProvider)
        returns (OracleProviderProperties memory)
    {
        (
            uint32 minTakeProfitBPS,
            uint32 maxTakeProfitBPS,
            uint8 leverageLevel
        ) = _oracleProviderRegistry.getOracleProviderProperties(oracleProvider);

        return
            OracleProviderProperties({
                minTakeProfitBPS: minTakeProfitBPS,
                maxTakeProfitBPS: maxTakeProfitBPS,
                leverageLevel: leverageLevel
            });
    }

    /**
     * @inheritdoc IOracleProviderRegistry
     * @dev This function can only be called by the DAO and registered oracle providers.
     */
    function updateTakeProfitBPSRange(
        address oracleProvider,
        uint32 minTakeProfitBPS,
        uint32 maxTakeProfitBPS
    ) external override onlyDao onlyRegisteredOracleProvider(oracleProvider) {
        _oracleProviderRegistry.setTakeProfitBPSRange(
            oracleProvider,
            minTakeProfitBPS,
            maxTakeProfitBPS
        );
        emit UpdateTakeProfitBPSRange(oracleProvider, minTakeProfitBPS, maxTakeProfitBPS);
    }

    /**
     * @inheritdoc IOracleProviderRegistry
     * @dev This function can only be called by the DAO and registered oracle providers.
     */
    function updateLeverageLevel(
        address oracleProvider,
        uint8 level
    ) external override onlyDao onlyRegisteredOracleProvider(oracleProvider) {
        require(level <= 1);
        _oracleProviderRegistry.setLeverageLevel(oracleProvider, level);
        emit UpdateLeverageLevel(oracleProvider, level);
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

        emit SettlementTokenRegistered(
            token,
            minimumMargin,
            interestRate,
            flashLoanFeeRate,
            earningDistributionThreshold,
            uniswapFeeTier
        );

        IKeeperFeePayer(keeperFeePayer).approveToRouter(token, true);
        IChromaticVault(vault).createMakerEarningDistributionTask(token);
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
}
