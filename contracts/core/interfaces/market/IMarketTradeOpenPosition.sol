// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {OpenPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";

/**
 * @title IMarketTradeOpenPosition
 * @dev Interface for open positions in a market.
 */
interface IMarketTradeOpenPosition {
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
}
