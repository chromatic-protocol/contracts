// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ITrade} from "@chromatic-protocol/contracts/core/interfaces/market/ITrade.sol";
import {ILiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/ILiquidity.sol";
import {IMarketState} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketState.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";

/**
 * @title IChromaticMarket
 * @dev Interface for the Chromatic Market contract, which combines trade and liquidity functionalities.
 */
interface IChromaticMarket is ITrade, ILiquidity, IMarketState, IMarketLiquidate {
    /**
     * @notice Executes the settlement process for the Chromatic market.
     * @dev This function is called to settle the market.
     */
    function settle() external;
}
