// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ClosePositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";

/**
 * @title IMarketTradeClosePosition
 * @dev Interface for closing and claiming positions in a market.
 */
interface IMarketTradeClosePosition {
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
}
