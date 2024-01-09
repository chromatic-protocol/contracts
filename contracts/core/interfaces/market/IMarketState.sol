// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {PositionMode, LiquidityMode, DisplayMode} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";

/**
 * @title IMarketState
 * @dev Interface for accessing the state of a market contract.
 */
interface IMarketState {
    /**
     * @notice Emitted when the protocol fee rate of the market is changed
     * @param protocolFeeRateOld The previous value of the protocol fee rate
     * @param protocolFeeRateNew The updated value of the protocol fee rate
     */
    event ProtocolFeeRateUpdated(uint16 protocolFeeRateOld, uint16 protocolFeeRateNew);

    /**
     * @notice Emitted when the position mode of the market is changed
     * @param positionModeOld The previous value of the position mode
     * @param positionModeNew The updated value of the position mode
     */
    event PositionModeUpdated(PositionMode positionModeOld, PositionMode positionModeNew);

    /**
     * @notice Emitted when the liquidity mode of the market is changed
     * @param liquidityModeOld The previous value of the liquidity mode
     * @param liquidityModeNew The updated value of the liquidity mode
     */
    event LiquidityModeUpdated(LiquidityMode liquidityModeOld, LiquidityMode liquidityModeNew);

    /**
     * @notice Emitted when the display mode of the market is changed
     * @param displayModeOld The previous value of the display mode
     * @param displayModeNew The updated value of the display mode
     */
    event DisplayModeUpdated(DisplayMode displayModeOld, DisplayMode displayModeNew);

    /**
     * @dev Returns the factory contract for the market.
     * @return The factory contract.
     */
    function factory() external view returns (IChromaticMarketFactory);

    /**
     * @dev Returns the settlement token of the market.
     * @return The settlement token.
     */
    function settlementToken() external view returns (IERC20Metadata);

    /**
     * @dev Returns the oracle provider contract for the market.
     * @return The oracle provider contract.
     */
    function oracleProvider() external view returns (IOracleProvider);

    /**
     * @dev Returns the CLB token contract for the market.
     * @return The CLB token contract.
     */
    function clbToken() external view returns (ICLBToken);

    /**
     * @dev Returns the vault contract for the market.
     * @return The vault contract.
     */
    function vault() external view returns (IChromaticVault);

    /**
     * @notice Returns the protocol fee rate
     * @return The protocol fee rate for the market
     */
    function protocolFeeRate() external view returns (uint16);

    /**
     * @notice Update the new protocol fee rate
     * @param _protocolFeeRate new protocol fee rate for the market
     */
    function updateProtocolFeeRate(uint16 _protocolFeeRate) external;

    /**
     * @notice Returns the position mode
     * @return The position mode for the market
     */
    function positionMode() external view returns (PositionMode);

    /**
     * @notice Update the new position mode
     * @param _positionMode new position mode for the market
     */
    function updatePositionMode(PositionMode _positionMode) external;

    /**
     * @notice Returns the liquidity mode
     * @return The liquidity mode for the market
     */
    function liquidityMode() external view returns (LiquidityMode);

    /**
     * @notice Update the new liquidity mode
     * @param _liquidityMode new liquidity mode for the market
     */
    function updateLiquidityMode(LiquidityMode _liquidityMode) external;

    /**
     * @notice Returns the display mode
     * @return The display mode for the market
     */
    function displayMode() external view returns (DisplayMode);

    /**
     * @notice Update the new display mode
     * @param _displayMode new display mode for the market
     */
    function updateDisplayMode(DisplayMode _displayMode) external;
}
