// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev The BinMargin struct represents the margin information for an LP bin.
 * @param tradingFeeRate The trading fee rate associated with the LP bin
 * @param amount The maker margin amount specified for the LP bin
 */
struct BinMargin {
    uint16 tradingFeeRate;
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
     * @param _protocolFeeRate The protocol fee rate for the market
     * @return The trading fee amount
     */
    function tradingFee(
        BinMargin memory self,
        uint16 _protocolFeeRate
    ) internal pure returns (uint256) {
        uint256 _tradingFee = self.amount.mulDiv(self.tradingFeeRate, TRADING_FEE_RATE_PRECISION);
        return _tradingFee - _protocolFee(_tradingFee, _protocolFeeRate);
    }

    /**
     * @notice Calculates the protocol fee based on the margin amount and the trading fee rate.
     * @param self The BinMargin struct
     * @param _protocolFeeRate The protocol fee rate for the market
     * @return The protocol fee amount
     */
    function protocolFee(
        BinMargin memory self,
        uint16 _protocolFeeRate
    ) internal pure returns (uint256) {
        return
            _protocolFee(
                self.amount.mulDiv(self.tradingFeeRate, TRADING_FEE_RATE_PRECISION),
                _protocolFeeRate
            );
    }

    function _protocolFee(
        uint256 _tradingFee,
        uint16 _protocolFeeRate
    ) private pure returns (uint256) {
        return _tradingFee.mulDiv(_protocolFeeRate, TRADING_FEE_RATE_PRECISION);
    }
}
