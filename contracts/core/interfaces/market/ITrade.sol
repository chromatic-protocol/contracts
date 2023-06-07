// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {Position} from "@chromatic/core/libraries/Position.sol";

/**
 * @title ITrade
 * @dev Interface for trading positions in a market.
 */
interface ITrade {
    error ZeroTargetAmount();
    error TooSmallTakerMargin();
    error NotEnoughMarginTransfered();
    error NotExistPosition();
    error NotPermitted();
    error AlreadyClosedPosition();
    error NotClaimablePosition();
    error ExceedMaxAllowableTradingFee();
    error ClaimPositionCallbackError();

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
     * @dev Emitted when a position is liquidated.
     * @param account The address of the account being liquidated.
     * @param usedKeeperFee The amount of keeper fee used for the liquidation.
     * @param position The liquidated position.
     */
    event Liquidate(address indexed account, uint256 indexed usedKeeperFee, Position position);

    /**
     * @dev Opens a new position in the market.
     * @param qty The quantity of the position.
     * @param leverage The leverage of the position in basis points.
     * @param takerMargin The margin amount provided by the taker.
     * @param makerMargin The margin amount provided by the maker.
     * @param maxAllowableTradingFee The maximum allowable trading fee for the position.
     * @param data Additional data for the position callback.
     * @return The opened position.
     */
    function openPosition(
        int224 qty,
        uint32 leverage, // BPS
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) external returns (Position memory);

    /**
     * @dev Closes a position in the market.
     * @param positionId The ID of the position to close.
     */
    function closePosition(uint256 positionId) external;

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
