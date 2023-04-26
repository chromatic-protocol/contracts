// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

uint256 constant TRADING_FEE_RATE_PRECISION = 10000;

struct LpSlotMargin {
    uint16 tradingFeeRate;
    uint256 amount;
}

using LpSlotMarginLib for LpSlotMargin global;

library LpSlotMarginLib {
    using Math for uint256;

    function tradingFee(
        LpSlotMargin memory self
    ) internal pure returns (uint256) {
        return
            self.amount.mulDiv(self.tradingFeeRate, TRADING_FEE_RATE_PRECISION);
    }
}
