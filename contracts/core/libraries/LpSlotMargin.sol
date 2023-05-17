// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @dev LpSlotMargin type
struct LpSlotMargin {
    /// @dev The trading fee rate, representing `LpSlot` key
    uint16 tradingFeeRate;
    /// @dev The maker margin amount from `LpSlot` specified by `tradingFeeRate`
    uint256 amount;
}

using LpSlotMarginLib for LpSlotMargin global;

/**
 * @title LpSlotMarginLib
 */
library LpSlotMarginLib {
    using Math for uint256;

    uint256 constant TRADING_FEE_RATE_PRECISION = 10000;

    /**
     * @notice Calculates the trading fee based on the margin amount and the trading fee rate.
     * @param self The memory instance of `LpSlotMargin` struct
     * @return uint256 The trading fee
     */
    function tradingFee(
        LpSlotMargin memory self
    ) internal pure returns (uint256) {
        return
            self.amount.mulDiv(self.tradingFeeRate, TRADING_FEE_RATE_PRECISION);
    }
}
