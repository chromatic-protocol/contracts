// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
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
     * @dev Returns the vault contract for the market.
     * @return The vault contract.
     */
    function vault() external view returns (IChromaticVault);

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
