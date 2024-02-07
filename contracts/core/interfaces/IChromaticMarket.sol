// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IMarketTradeOpenPosition} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTradeOpenPosition.sol";
import {IMarketTradeClosePosition} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTradeClosePosition.sol";
import {IMarketLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidity.sol";
import {IMarketLens} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLens.sol";
import {IMarketState} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketState.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";
import {IMarketSettle} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketSettle.sol";
import {IMarketEvents} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketEvents.sol";
import {IMarketErrors} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketErrors.sol";

/**
 * @title IChromaticMarket
 * @dev Interface for the Chromatic Market contract, which combines trade and liquidity functionalities.
 */
interface IChromaticMarket is
    IMarketEvents,
    IMarketErrors,
    IMarketTradeOpenPosition,
    IMarketTradeClosePosition,
    IMarketLiquidity,
    IMarketLens,
    IMarketState,
    IMarketLiquidate,
    IMarketSettle
{

}
