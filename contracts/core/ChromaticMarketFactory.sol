// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IInterestCalculator} from "@chromatic-protocol/contracts/core/interfaces/IInterestCalculator.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
import {IMarketSettlement} from "@chromatic-protocol/contracts/core/interfaces/IMarketSettlement.sol";
import {IMarketDeployer} from "@chromatic-protocol/contracts/core/interfaces/factory/IMarketDeployer.sol";
import {IOracleProviderRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/IOracleProviderRegistry.sol";
import {ISettlementTokenRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/ISettlementTokenRegistry.sol";
import {IMarketState} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketState.sol";
import {OracleProviderProperties, OracleProviderPropertiesLib} from "@chromatic-protocol/contracts/core/libraries/registry/OracleProviderProperties.sol";
import {OracleProviderRegistry, OracleProviderRegistryLib} from "@chromatic-protocol/contracts/core/libraries/registry/OracleProviderRegistry.sol";
import {SettlementTokenRegistry, SettlementTokenRegistryLib} from "@chromatic-protocol/contracts/core/libraries/registry/SettlementTokenRegistry.sol";
import {InterestRate} from "@chromatic-protocol/contracts/core/libraries/InterestRate.sol";
import {MarketDeployer, MarketDeployerLib, Parameters, DeployArgs} from "@chromatic-protocol/contracts/core/libraries/deployer/MarketDeployer.sol";

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
    address public override marketSettlement;
    uint16 public override defaultProtocolFeeRate;

    address private immutable marketDiamondCutFacet;
    address private immutable marketLoupeFacet;
    address private immutable marketStateFacet;
    address private immutable marketAddLiquidityFacet;
    address private immutable marketRemoveLiquidityFacet;
    address private immutable marketLensFacet;
    address private immutable marketTradeOpenPositionFacet;
    address private immutable marketTradeClosePositionFacet;
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
     * @dev Throws an error indicating that the chromatic vault address is already set.
     */
    error AlreadySetVault();

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
        _checkDao();
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
     * @param _marketAddLiquidityFacet The market liquidity facet address for adding and claiming liquidity.
     * @param _marketRemoveLiquidityFacet The market liquidity facet address for removing and withdrawing liquidity.
     * @param _marketLiquidityLensFacet The market liquidity lens facet address.
     * @param _marketTradeOpenPositionFacet The market trade facet address for opening positions.
     * @param _marketTradeClosePositionFacet The market trade facet address for closing and claiming positions.
     * @param _marketLiquidateFacet The market liquidate facet address.
     * @param _marketSettleFacet The market settle facet address.
     */
    constructor(
        address _marketDiamondCutFacet,
        address _marketLoupeFacet,
        address _marketStateFacet,
        address _marketAddLiquidityFacet,
        address _marketRemoveLiquidityFacet,
        address _marketLiquidityLensFacet,
        address _marketTradeOpenPositionFacet,
        address _marketTradeClosePositionFacet,
        address _marketLiquidateFacet,
        address _marketSettleFacet
    ) {
        require(_marketDiamondCutFacet != address(0));
        require(_marketLoupeFacet != address(0));
        require(_marketStateFacet != address(0));
        require(_marketAddLiquidityFacet != address(0));
        require(_marketRemoveLiquidityFacet != address(0));
        require(_marketLiquidityLensFacet != address(0));
        require(_marketTradeOpenPositionFacet != address(0));
        require(_marketTradeClosePositionFacet != address(0));
        require(_marketLiquidateFacet != address(0));
        require(_marketSettleFacet != address(0));

        dao = msg.sender;
        treasury = dao;

        marketDiamondCutFacet = _marketDiamondCutFacet;
        marketLoupeFacet = _marketLoupeFacet;
        marketStateFacet = _marketStateFacet;
        marketAddLiquidityFacet = _marketAddLiquidityFacet;
        marketRemoveLiquidityFacet = _marketRemoveLiquidityFacet;
        marketLensFacet = _marketLiquidityLensFacet;
        marketTradeOpenPositionFacet = _marketTradeOpenPositionFacet;
        marketTradeClosePositionFacet = _marketTradeClosePositionFacet;
        marketLiquidateFacet = _marketLiquidateFacet;
        marketSettleFacet = _marketSettleFacet;
    }

    /**
     * @dev This function can only be called by the modifier onlyDao.
     */
    function _checkDao() internal view {
        if (msg.sender != dao) revert OnlyAccessableByDao();
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateDao(address _dao) external override onlyDao {
        require(_dao != address(0));
        address daoOld = dao;
        dao = _dao;
        emit DaoUpdated(daoOld, dao);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateTreasury(address _treasury) external override onlyDao {
        require(_treasury != address(0));
        address treasuryOld = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(treasuryOld, treasury);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateLiquidator(address _liquidator) external override onlyDao {
        require(_liquidator != address(0));
        address liquidatorOld = liquidator;
        liquidator = _liquidator;
        emit LiquidatorUpdated(liquidatorOld, liquidator);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateKeeperFeePayer(address _keeperFeePayer) external override onlyDao {
        require(_keeperFeePayer != address(0));
        address keeperFeePayerOld = keeperFeePayer;
        keeperFeePayer = _keeperFeePayer;
        emit KeeperFeePayerUpdated(keeperFeePayerOld, keeperFeePayer);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateDefaultProtocolFeeRate(
        uint16 _defaultProtocolFeeRate
    ) external override onlyDao {
        require(_defaultProtocolFeeRate <= 5000); // 50%
        uint16 defaultProtocolFeeRateOld = defaultProtocolFeeRate;
        defaultProtocolFeeRate = _defaultProtocolFeeRate;
        emit DefaultProtocolFeeRateUpdated(defaultProtocolFeeRateOld, defaultProtocolFeeRate);
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
        emit VaultSet(vault);
    }

    /**
     * @inheritdoc IChromaticMarketFactory
     * @dev This function can only be called by the DAO address.
     */
    function updateMarketSettlement(address _marketSettlement) external override onlyDao {
        require(_marketSettlement != address(0));
        address marketSettlementOld = marketSettlement;
        marketSettlement = _marketSettlement;
        emit MarketSettlementUpdated(marketSettlementOld, marketSettlement);
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
                ++i;
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
            DeployArgs({
                oracleProvider: oracleProvider,
                settlementToken: settlementToken,
                marketDiamondCutFacet: marketDiamondCutFacet,
                marketLoupeFacet: marketLoupeFacet,
                marketStateFacet: marketStateFacet,
                marketAddLiquidityFacet: marketAddLiquidityFacet,
                marketRemoveLiquidityFacet: marketRemoveLiquidityFacet,
                marketLensFacet: marketLensFacet,
                marketTradeOpenPositionFacet: marketTradeOpenPositionFacet,
                marketTradeClosePositionFacet: marketTradeClosePositionFacet,
                marketLiquidateFacet: marketLiquidateFacet,
                marketSettleFacet: marketSettleFacet,
                protocolFeeRate: defaultProtocolFeeRate
            })
        );

        //slither-disable-next-line reentrancy-benign
        _marketsBySettlementToken[settlementToken].push(market);
        //slither-disable-next-line unused-return
        _markets.add(market);

        //slither-disable-next-line reentrancy-events
        emit MarketCreated(oracleProvider, settlementToken, market);

        IChromaticVault(vault).createMarketEarningDistributionTask(market);
        if (marketSettlement != address(0)) {
            IMarketSettlement(marketSettlement).createSettlementTask(market);
        }
    }

    /**
     * @inheritdoc IMarketDeployer
     */
    function parameters()
        external
        view
        override
        returns (address oracleProvider, address settlementToken, uint16 protocolFeeRate)
    {
        Parameters memory params = _deployer.parameters;
        return (params.oracleProvider, params.settlementToken, params.protocolFeeRate);
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
        require(OracleProviderPropertiesLib.checkValidLeverageLevel(properties.leverageLevel));
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
        require(OracleProviderPropertiesLib.checkValidLeverageLevel(level));
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
        address oracleProvider,
        uint256 minimumMargin,
        uint256 interestRate,
        uint256 flashLoanFeeRate,
        uint256 earningDistributionThreshold,
        uint24 uniswapFeeTier
    ) external override onlyDao {
        require(token != address(0));
        require(oracleProvider != address(0));

        _settlementTokenRegistry.register(
            token,
            oracleProvider,
            minimumMargin,
            interestRate,
            flashLoanFeeRate,
            earningDistributionThreshold,
            uniswapFeeTier
        );

        emit SettlementTokenRegistered(
            token,
            oracleProvider,
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
    function getSettlementTokenOracleProvider(address token) external view returns (address) {
        return _settlementTokenRegistry.getOracleProvider(token);
    }

    /**
     * @inheritdoc ISettlementTokenRegistry
     * @dev This function can only be called by the DAO address.
     */
    function setSettlementTokenOracleProvider(
        address token,
        address oracleProvider
    ) external onlyDao {
        require(oracleProvider != address(0));
        _settlementTokenRegistry.setOracleProvider(token, oracleProvider);
        emit SetSettlementTokenOracleProvider(token, oracleProvider);
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
