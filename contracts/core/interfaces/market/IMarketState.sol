// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticLiquidator} from "@chromatic-protocol/contracts/core/interfaces/IChromaticLiquidator.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";

/**
 * @title IMarketState
 * @dev Interface for accessing the state of a market contract.
 */
interface IMarketState {
    /**
     * @notice Emitted when the protocol fee is changed by the market
     * @param feeProtocolOld The previous value of the protocol fee
     * @param feeProtocolNew The updated value of the protocol fee
     */
    event SetFeeProtocol(uint8 feeProtocolOld, uint8 feeProtocolNew);

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
     * @dev Returns the liquidator contract for the market.
     * @return The liquidator contract.
     */
    function liquidator() external view returns (IChromaticLiquidator);

    /**
     * @dev Returns the vault contract for the market.
     * @return The vault contract.
     */
    function vault() external view returns (IChromaticVault);

    /**
     * @dev Returns the keeper fee payer contract for the market.
     * @return The keeper fee payer contract.
     */
    function keeperFeePayer() external view returns (IKeeperFeePayer);

    /**
     * @notice Returns the denominator of the protocol's % share of the fees
     * @return The protocol fee for the market
     */
    function feeProtocol() external view returns (uint8);

    /**
     * @notice Set the denominator of the protocol's % share of the fees
     * @param _feeProtocol new protocol fee for the market
     */
    function setFeeProtocol(uint8 _feeProtocol) external;
}
