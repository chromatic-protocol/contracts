// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {OpenPositionInfo, ClosePositionInfo, ClaimPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTrade.sol";

/**
 * @title IChromaticAccount
 * @dev Interface for the ChromaticAccount contract, which manages user accounts and positions.
 */
interface IChromaticAccount is IChromaticTradeCallback {
    /**
     * @dev Emitted when a position is opened.
     * @param marketAddress The address of the market.
     * @param positionId The position identifier
     * @param openVersion The version of the oracle when the position was opened
     * @param qty The quantity of the position
     * @param openTimestamp The timestamp when the position was opened
     * @param takerMargin The amount of collateral that a trader must provide
     * @param makerMargin The margin amount provided by the maker.
     * @param tradingFee The trading fee associated with the position.
     */
    event OpenPosition(
        address indexed marketAddress,
        uint256 indexed positionId,
        uint256 openVersion,
        int256 qty,
        uint256 openTimestamp,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 tradingFee
    );

    /**
     * @dev Emitted when a position is closed.
     * @param marketAddress The address of the market.
     * @param positionId The position identifier
     * @param closeVersion The version of the oracle when the position was closed
     * @param closeTimestamp The timestamp when the position was closed
     */
    event ClosePosition(
        address indexed marketAddress,
        uint256 indexed positionId,
        uint256 closeVersion,
        uint256 closeTimestamp
    );

    /**
     * @dev Emitted when a position is claimed.
     * @param marketAddress The address of the market.
     * @param positionId The position identifier
     * @param entryPrice The entry price of the position
     * @param exitPrice The exit price of the position
     * @param realizedPnl The profit or loss of the claimed position.
     * @param interest The interest paid for the claimed position.
     * @param cause The description of being claimed.
     */
    event ClaimPosition(
        address indexed marketAddress,
        uint256 indexed positionId,
        uint256 entryPrice,
        uint256 exitPrice,
        int256 realizedPnl,
        uint256 interest,
        bytes4 cause
    );

    /**
     * @notice Returns the balance of the specified token for the account.
     * @param token The address of the token.
     * @return The balance of the token.
     */
    function balance(address token) external view returns (uint256);

    /**
     * @notice Withdraws the specified amount of tokens from the account.
     * @param token The address of the token to withdraw.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(address token, uint256 amount) external;

    /**
     * @notice Checks if the specified market has the specified position ID.
     * @param marketAddress The address of the market.
     * @param positionId The ID of the position.
     * @return A boolean indicating whether the market has the position ID.
     */
    function hasPositionId(address marketAddress, uint256 positionId) external view returns (bool);

    /**
     * @notice Retrieves an array of position IDs owned by this account for the specified market.
     * @param marketAddress The address of the market.
     * @return An array of position IDs.
     */
    function getPositionIds(address marketAddress) external view returns (uint256[] memory);

    /**
     * @notice Opens a new position in the specified market.
     * @param marketAddress The address of the market.
     * @param qty The quantity of the position.
     * @param takerMargin The margin required for the taker.
     * @param makerMargin The margin required for the maker.
     * @param maxAllowableTradingFee The maximum allowable trading fee.
     * @return openPositionInfo The opened position information.
     */
    function openPosition(
        address marketAddress,
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external returns (OpenPositionInfo memory);

    /**
     * @notice Closes the specified position in the specified market.
     * @param marketAddress The address of the market.
     * @param positionId The ID of the position to close.
     */
    function closePosition(address marketAddress, uint256 positionId) external;

    /**
     * @notice Claims the specified position in the specified market.
     * @param marketAddress The address of the market.
     * @param positionId The ID of the position to claim.
     */
    function claimPosition(address marketAddress, uint256 positionId) external;
}
