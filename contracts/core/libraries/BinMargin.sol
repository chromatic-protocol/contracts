// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title BinMargin
 * @dev The BinMargin struct represents the margin information for an LP bin.
 */
struct BinMargin {
    /// @dev The trading fee rate associated with the LP bin
    uint16 tradingFeeRate;
    /// @dev The maker margin amount specified for the LP bin
    uint256 amount;
}

using BinMarginLib for BinMargin global;

/**
 * @title BinMarginLib
 * @dev The BinMarginLib library provides functions to operate on BinMargin structs.
 */
library BinMarginLib {
    using Math for uint256;

    uint256 constant TRADING_FEE_RATE_PRECISION = 10000;

    /**
     * @notice Calculates the trading fee based on the margin amount and the trading fee rate.
     * @param self The BinMargin struct
     * @return The trading fee amount
     */
    function tradingFee(BinMargin memory self) internal pure returns (uint256) {
        return self.amount.mulDiv(self.tradingFeeRate, TRADING_FEE_RATE_PRECISION);
    }
}
