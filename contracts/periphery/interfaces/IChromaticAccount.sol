// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";

/**
 * @title IChromaticAccount
 * @dev Interface for the ChromaticAccount contract, which manages user accounts and positions.
 */
interface IChromaticAccount is IChromaticTradeCallback {
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
     * @param leverage The leverage of the position.
     * @param takerMargin The margin required for the taker.
     * @param makerMargin The margin required for the maker.
     * @param maxAllowableTradingFee The maximum allowable trading fee.
     * @return position The opened position.
     */
    function openPosition(
        address marketAddress,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external returns (Position memory);

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
