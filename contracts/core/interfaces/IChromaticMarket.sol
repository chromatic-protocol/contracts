// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {ITrade} from "@chromatic/core/interfaces/market/ITrade.sol";
import {ILiquidity} from "@chromatic/core/interfaces/market/ILiquidity.sol";
import {IMarketState} from "@chromatic/core/interfaces/market/IMarketState.sol";
import {IMarketLiquidate} from "@chromatic/core/interfaces/market/IMarketLiquidate.sol";

interface IChromaticMarket is ITrade, ILiquidity, IMarketState, IMarketLiquidate {
    function settle() external;
}
