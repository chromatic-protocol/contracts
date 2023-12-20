// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IInterestCalculator} from "@chromatic-protocol/contracts/core/interfaces/IInterestCalculator.sol";
import {IMarketDeployer} from "@chromatic-protocol/contracts/core/interfaces/factory/IMarketDeployer.sol";
import {ISettlementTokenRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/ISettlementTokenRegistry.sol";
import {IOracleProviderRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/IOracleProviderRegistry.sol";

/**
 * @title IChromaticMarketFactory
 * @dev Interface for the Chromatic Market Factory contract.
 */
interface IChromaticMarketFactory is
    IMarketDeployer,
    IOracleProviderRegistry,
    ISettlementTokenRegistry,
    IInterestCalculator
{
    /**
     * @notice Emitted when the DAO address is updated.
     * @param daoOld The old DAO address.
     * @param daoNew The new DAO address.
     */
    event DaoUpdated(address indexed daoOld, address indexed daoNew);

    /**
     * @notice Emitted when the DAO treasury address is updated.
     * @param treasuryOld The old DAO treasury address.
     * @param treasuryNew The new DAO treasury address.
     */
    event TreasuryUpdated(address indexed treasuryOld, address indexed treasuryNew);

    /**
     * @notice Emitted when the liquidator address is updated.
     * @param liquidatorOld The old liquidator address.
     * @param liquidatorNew The new liquidator address.
     */
    event LiquidatorUpdated(address indexed liquidatorOld, address indexed liquidatorNew);

    /**
     * @notice Emitted when the keeper fee payer address is updated.
     * @param keeperFeePayerOld The old keeper fee payer address.
     * @param keeperFeePayerNew The new keeper fee payer address.
     */
    event KeeperFeePayerUpdated(
        address indexed keeperFeePayerOld,
        address indexed keeperFeePayerNew
    );

    /**
     * @notice Emitted when the default protocol fee rate is updated.
     * @param defaultProtocolFeeRateOld The old default protocol fee rate.
     * @param defaultProtocolFeeRateNew The new default protocol fee rate.
     */
    event DefaultProtocolFeeRateUpdated(
        uint16 indexed defaultProtocolFeeRateOld,
        uint16 indexed defaultProtocolFeeRateNew
    );

    /**
     * @notice Emitted when the vault address is set.
     * @param vault The vault address.
     */
    event VaultSet(address indexed vault);

    /**
     * @notice Emitted when the market settlement task address is updated.
     * @param marketSettlementOld The old market settlement task address.
     * @param marketSettlementNew The new market settlement task address.
     */
    event MarketSettlementUpdated(
        address indexed marketSettlementOld,
        address indexed marketSettlementNew
    );

    /**
     * @notice Emitted when a market is created.
     * @param oracleProvider The address of the oracle provider.
     * @param settlementToken The address of the settlement token.
     * @param market The address of the created market.
     */
    event MarketCreated(
        address indexed oracleProvider,
        address indexed settlementToken,
        address indexed market
    );

    /**
     * @notice Returns the address of the DAO.
     * @return The address of the DAO.
     */
    function dao() external view returns (address);

    /**
     * @notice Returns the address of the DAO treasury.
     * @return The address of the DAO treasury.
     */
    function treasury() external view returns (address);

    /**
     * @notice Returns the address of the liquidator.
     * @return The address of the liquidator.
     */
    function liquidator() external view returns (address);

    /**
     * @notice Returns the address of the vault.
     * @return The address of the vault.
     */
    function vault() external view returns (address);

    /**
     * @notice Returns the address of the keeper fee payer.
     * @return The address of the keeper fee payer.
     */
    function keeperFeePayer() external view returns (address);

    /**
     * @notice Returns the address of the market settlement task.
     * @return The address of the market settlement task.
     */
    function marketSettlement() external view returns (address);

    /**
     * @notice Returns the default protocol fee rate.
     * @return The default protocol fee rate.
     */
    function defaultProtocolFeeRate() external view returns (uint16);

    /**
     * @notice Updates the DAO address.
     * @param _dao The new DAO address.
     */
    function updateDao(address _dao) external;

    /**
     * @notice Updates the DAO treasury address.
     * @param _treasury The new DAO treasury address.
     */
    function updateTreasury(address _treasury) external;

    /**
     * @notice Updates the liquidator address.
     * @param _liquidator The new liquidator address.
     */
    function updateLiquidator(address _liquidator) external;

    /**
     * @notice Updates the keeper fee payer address.
     * @param _keeperFeePayer The new keeper fee payer address.
     */
    function updateKeeperFeePayer(address _keeperFeePayer) external;

    /**
     * @notice Updates the default protocl fee rate.
     * @param _defaultProtocolFeeRate The new default protocol fee rate.
     */
    function updateDefaultProtocolFeeRate(uint16 _defaultProtocolFeeRate) external;

    /**
     * @notice Sets the vault address.
     * @param _vault The vault address.
     */
    function setVault(address _vault) external;

    /**
     * @notice Updates the market settlement task address.
     * @param _marketSettlement The new market settlement task address.
     */
    function updateMarketSettlement(address _marketSettlement) external;

    /**
     * @notice Returns an array of all market addresses.
     * @return markets An array of all market addresses.
     */
    function getMarkets() external view returns (address[] memory markets);

    /**
     * @notice Returns an array of market addresses associated with a settlement token.
     * @param settlementToken The address of the settlement token.
     * @return An array of market addresses.
     */
    function getMarketsBySettlmentToken(
        address settlementToken
    ) external view returns (address[] memory);

    /**
     * @notice Returns the address of a market associated with an oracle provider and settlement token.
     * @param oracleProvider The address of the oracle provider.
     * @param settlementToken The address of the settlement token.
     * @return The address of the market.
     */
    function getMarket(
        address oracleProvider,
        address settlementToken
    ) external view returns (address);

    /**
     * @notice Creates a new market associated with an oracle provider and settlement token.
     * @param oracleProvider The address of the oracle provider.
     * @param settlementToken The address of the settlement token.
     */
    function createMarket(address oracleProvider, address settlementToken) external;

    /**
     * @notice Checks if a market is registered.
     * @param market The address of the market.
     * @return True if the market is registered, false otherwise.
     */
    function isRegisteredMarket(address market) external view returns (bool);
}
