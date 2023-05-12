// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {MarketBase} from "@usum/core/base/market/MarketBase.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotSet} from "@usum/core/external/lpslot/LpSlotSet.sol";
import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";

abstract contract MarketValue is MarketBase {
    function newLpContext() internal view returns (LpContext memory) {
        return
            LpContext({
                market: this,
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
            factory.calculateInterest(
                address(settlementToken),
                amount,
                from,
                to,
                rounding
            );
    }

    function _indexPrice() internal view returns (int256) {
        return oracleProvider.currentVersion().price;
    }
}
