// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {MarketBase} from "@usum/core/base/market/MarketBase.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotSet} from "@usum/core/external/lpslot/LpSlotSet.sol";

abstract contract MarketValue is MarketBase {
    function newLpContext() internal view returns (LpContext memory ctx) {
        ctx.market = this;
        ctx.tokenPrecision = 10 ** settlementToken.decimals();
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
}
