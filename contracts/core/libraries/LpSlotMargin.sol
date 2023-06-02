// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title LpSlotMargin
 * @dev The LpSlotMargin struct represents the margin information for an LP slot.
 */
struct LpSlotMargin {
    /// @dev The trading fee rate associated with the LP slot
    uint16 tradingFeeRate;
    /// @dev The maker margin amount specified for the LP slot
    uint256 amount;
}

using LpSlotMarginLib for LpSlotMargin global;

/**
 * @title LpSlotMarginLib
 * @dev The LpSlotMarginLib library provides functions to operate on LpSlotMargin structs.
 */
library LpSlotMarginLib {
    using Math for uint256;

    uint256 constant TRADING_FEE_RATE_PRECISION = 10000;

    /**
     * @notice Calculates the trading fee based on the margin amount and the trading fee rate.
     * @param self The LpSlotMargin struct
     * @return The trading fee amount
     */
    function tradingFee(LpSlotMargin memory self) internal pure returns (uint256) {
        return self.amount.mulDiv(self.tradingFeeRate, TRADING_FEE_RATE_PRECISION);
    }
}
