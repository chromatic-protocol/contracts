// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IInterestCalculator} from '@usum/core/interfaces/market/IInterestCalculator.sol';
import {ITrade} from '@usum/core/interfaces/market/ITrade.sol';
import {IUSUMLiquidity} from '@usum/core/interfaces/market/IUSUMLiquidity.sol';
import {IUSUMMarketState} from '@usum/core/interfaces/market/IUSUMMarketState.sol';
import {IUSUMMarketLiquidate} from '@usum/core/interfaces/market/IUSUMMarketLiquidate.sol';

interface IUSUMMarket is IInterestCalculator, ITrade, IUSUMLiquidity, IUSUMMarketState, IUSUMMarketLiquidate {
    function settle() external;
}
