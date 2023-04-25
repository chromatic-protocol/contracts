// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {MarketBase} from "@usum/core/base/market/MarketBase.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotSet} from "@usum/core/libraries/LpSlotSet.sol";
import {LpSlot} from "@usum/core/libraries/LpSlot.sol";
import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";
import {ISettlementTokenRegistry} from "@usum/core/interfaces/ISettlementTokenRegistry.sol";

abstract contract MarketValue is MarketBase, IInterestCalculator {
    function newLpContext() internal view returns (LpContext memory) {
        return
            LpContext({
                oracleProvider: oracleProvider,
                interestCalculator: this,
                tokenPrecision: 10 ** settlementToken.decimals(),
                _pricePrecision: 0,
                _currentVersionCache: OracleVersion(0, 0, 0)
            });
    }

    function calculateInterest(
        uint256 amount,
        uint256 from,
        uint256 to
    ) public view override returns (uint256) {
        return calculateInterest(amount, from, to, Math.Rounding.Down);
    }

    function calculateInterest(
        uint256 amount,
        uint256 from,
        uint256 to,
        Math.Rounding rounding // use Rouding.Up to deduct accumulated accrued interest
    ) public view override returns (uint256) {
        return
            ISettlementTokenRegistry(address(factory)).calculateInterest(
                address(settlementToken),
                amount,
                from,
                to,
                rounding
            );
    }

    function _balance() internal view returns (uint256) {
        return settlementToken.balanceOf(address(this));
    }

    function _lpPoolSize() internal view returns (uint256) {
        // return
        //     _balance() -
        //     (poolInfo.totalTakerMargin.long + poolInfo.totalTakerMargin.short);
    }

    function _lpReserve() internal view returns (uint256) {
        // return _lpPoolSize().mulDiv(lpReserveRatio, BPS);
    }

    function _unusedMargin() internal view returns (uint256) {
        // return
        //     _lpPoolSize() -
        //     (poolInfo.totalMakerMargin.long + poolInfo.totalMakerMargin.short);
    }

    function _checkMakerMarginEnough(uint256 requiredMargin) internal view {
        // if (_unusedMargin() > _lpReserve() + requiredMargin)
        //     revert NotEnoughMakerMargin();
    }

    function _indexPrice() internal view returns (int256) {
        return oracleProvider.currentVersion().price;
    }

    function _estimateMarketValue() internal view returns (uint256) {
        // // taker side positions
        // uint256 longPosition = poolInfo.totalTakerPosition.long;
        // uint256 shortPosition = poolInfo.totalTakerPosition.short;
        // uint256 currentPrice = vFuturePool.currentPrice(_indexPrice());
        // // maker's pnl of taker side positions
        // int256 longPnl = 0;
        // int256 shortPnl = 0;
        // if (longPosition > 0) {
        //     longPnl = poolInfo.totalTakerCost.long.sub(
        //         currentPrice * longPosition
        //     );
        //     if (longPnl > 0) {
        //         uint256 takerMargin = poolInfo.totalTakerMargin.long;
        //         if (uint256(longPnl) > takerMargin) {
        //             longPnl = int256(takerMargin);
        //         }
        //     } else {
        //         uint256 makerMargin = poolInfo.totalMakerMargin.long;
        //         if (uint256(-longPnl) > makerMargin) {
        //             longPnl = -int256(makerMargin);
        //         }
        //     }
        // }
        // if (shortPosition > 0) {
        //     shortPnl = (currentPrice * shortPosition).sub(
        //         poolInfo.totalTakerCost.short
        //     );
        //     if (shortPnl > 0) {
        //         uint256 takerMargin = poolInfo.totalTakerMargin.short;
        //         if (uint256(shortPnl) > takerMargin) {
        //             shortPnl = int256(takerMargin);
        //         }
        //     } else {
        //         uint256 makerMargin = poolInfo.totalMakerMargin.short;
        //         if (uint256(-shortPnl) > makerMargin) {
        //             shortPnl = -int256(makerMargin);
        //         }
        //     }
        // }
        // return
        //     (_lpPoolSize() + poolInfo.unsettledInterest()).add(
        //         longPnl + shortPnl
        //     );
    }
}