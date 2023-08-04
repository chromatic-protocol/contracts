// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";

/**
 * @dev The OpenPositionInfo struct represents a opened trading position.
 * @param id The position identifier
 * @param openVersion The version of the oracle when the position was opened
 * @param closeVersion The version of the oracle when the position was closed
 * @param qty The quantity of the position
 * @param openTimestamp The timestamp when the position was opened
 * @param closeTimestamp The timestamp when the position was closed
 * @param takerMargin The amount of collateral that a trader must provide
 * @param makerMargin The margin amount provided by the maker.
 * @param tradingFee The trading fee associated with the position.
 */
struct OpenPositionInfo {
    uint256 id;
    uint256 openVersion;
    int256 qty;
    uint256 openTimestamp;
    uint256 takerMargin;
    uint256 makerMargin;
    uint256 tradingFee;
}

/**
 * @dev The ClosePositionInfo struct represents a closed trading position.
 * @param id The position identifier
 * @param closeVersion The version of the oracle when the position was closed
 * @param closeTimestamp The timestamp when the position was closed
 */
struct ClosePositionInfo {
    uint256 id;
    uint256 closeVersion;
    uint256 closeTimestamp;
}

/**
 * @dev The ClaimPositionInfo struct represents a claimed position information.
 * @param id The position identifier
 * @param entryPrice The entry price of the position
 * @param exitPrice The exit price of the position
 * @param realizedPnl The profit or loss of the claimed position.
 * @param interest The interest paid for the claimed position.
 * @param cause The description of being claimed.
 */
struct ClaimPositionInfo {
    uint256 id;
    uint256 entryPrice;
    uint256 exitPrice;
    int256 realizedPnl;
    uint256 interest;
    bytes4 cause;
}

bytes4 constant CLAIM_USER = "UC";
bytes4 constant CLAIM_KEEPER = "KC";
bytes4 constant CLAIM_TP = "TP";
bytes4 constant CLAIM_SL = "SL";

/**
 * @title IMarketTrade
 * @dev Interface for trading positions in a market.
 */
interface IMarketTrade {
    /**
     * @dev Emitted when a position is opened.
     * @param account The address of the account opening the position.
     * @param position The opened position.
     */
    event OpenPosition(address indexed account, Position position);

    /**
     * @dev Emitted when a position is closed.
     * @param account The address of the account closing the position.
     * @param position The closed position.
     */
    event ClosePosition(address indexed account, Position position);

    /**
     * @dev Emitted when a position is claimed.
     * @param account The address of the account claiming the position.
     * @param pnl The profit or loss of the claimed position.
     * @param interest The interest paid for the claimed position.
     * @param position The claimed position.
     */
    event ClaimPosition(
        address indexed account,
        int256 indexed pnl,
        uint256 indexed interest,
        Position position
    );

    /**
     * @dev Emitted when protocol fees are transferred.
     * @param positionId The ID of the position for which the fees are transferred.
     * @param amount The amount of fees transferred.
     */
    event TransferProtocolFee(uint256 indexed positionId, uint256 indexed amount);

    /**
     * @dev Opens a new position in the market.
     * @param qty The quantity of the position.
     * @param takerMargin The margin amount provided by the taker.
     * @param makerMargin The margin amount provided by the maker.
     * @param maxAllowableTradingFee The maximum allowable trading fee for the position.
     * @param data Additional data for the position callback.
     * @return The opened position.
     */
    function openPosition(
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) external returns (OpenPositionInfo memory);

    /**
     * @dev Closes a position in the market.
     * @param positionId The ID of the position to close.
     * @return The closed position.
     */
    function closePosition(uint256 positionId) external returns (ClosePositionInfo memory);

    /**
     * @dev Claims a closed position in the market.
     * @param positionId The ID of the position to claim.
     * @param recipient The address of the recipient of the claimed position.
     * @param data Additional data for the claim callback.
     */
    function claimPosition(
        uint256 positionId,
        address recipient, // EOA or account contract
        bytes calldata data
    ) external;

    /**
     * @dev Retrieves multiple positions by their IDs.
     * @param positionIds The IDs of the positions to retrieve.
     * @return positions An array of retrieved positions.
     */
    function getPositions(
        uint256[] calldata positionIds
    ) external view returns (Position[] memory positions);
}
