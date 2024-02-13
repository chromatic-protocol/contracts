// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {FEE_RATES_LENGTH} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {Errors} from "@chromatic-protocol/contracts/core/libraries/Errors.sol";

/**
 * @title CLBTokenLib
 * @notice Provides utility functions for working with CLB tokens.
 */
library CLBTokenLib {
    using SignedMath for int256;
    using SafeCast for uint256;

    uint256 private constant DIRECTION_PRECISION = 10 ** 10;
    uint16 private constant MIN_FEE_RATE = 1;

    /**
     * @notice Encode the CLB token ID of ERC1155 token type
     * @dev If `tradingFeeRate` is negative, it adds `DIRECTION_PRECISION` to the absolute fee rate.
     *      Otherwise it returns the fee rate directly.
     * @return id The ID of ERC1155 token
     */
    function encodeId(int16 tradingFeeRate) internal pure returns (uint256) {
        bool long = tradingFeeRate > 0;
        return _encodeId(uint16(long ? tradingFeeRate : -tradingFeeRate), long);
    }

    /**
     * @notice Decode the trading fee rate from the CLB token ID of ERC1155 token type
     * @dev If `id` is greater than or equal to `DIRECTION_PRECISION`,
     *      then it substracts `DIRECTION_PRECISION` from `id`
     *      and returns the negation of the substracted value.
     *      Otherwise it returns `id` directly.
     * @return tradingFeeRate The trading fee rate
     */
    function decodeId(uint256 id) internal pure returns (int16 tradingFeeRate) {
        if (id >= DIRECTION_PRECISION) {
            tradingFeeRate = -int16((id - DIRECTION_PRECISION).toUint16());
        } else {
            tradingFeeRate = int16(id.toUint16());
        }
    }

    /**
     * @notice Retrieves the array of supported trading fee rates.
     * @dev This function returns the array of supported trading fee rates,
     *      ranging from the minimum fee rate to the maximum fee rate with step increments.
     * @return tradingFeeRates The array of supported trading fee rates.
     */
    function tradingFeeRates() internal pure returns (uint16[FEE_RATES_LENGTH] memory) {
        // prettier-ignore
        return [
            MIN_FEE_RATE, 2, 3, 4, 5, 6, 7, 8, 9, // 0.01% ~ 0.09%, step 0.01%
            10, 20, 30, 40, 50, 60, 70, 80, 90, // 0.1% ~ 0.9%, step 0.1%
            100, 200, 300, 400, 500, 600, 700, 800, 900, // 1% ~ 9%, step 1%
            1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000 // 10% ~ 50%, step 5%
        ];
    }

    function feeRateIndex(uint16 feeRate) internal pure returns (uint256) {
        require(feeRate >= MIN_FEE_RATE && feeRate <= 5000, Errors.UNSUPPORTED_TRADING_FEE_RATE);

        if (feeRate < 10) {
            // 0..8
            return feeRate - 1;
        } else if (feeRate < 100) {
            // 9..17
            return (feeRate / 10) + 8;
        } else if (feeRate < 1000) {
            // 18..26
            return (feeRate / 100) + 17;
        } else {
            // 27..35
            return (feeRate / 500) + 25;
        }
    }

    function tokenIds() internal pure returns (uint256[] memory) {
        uint16[FEE_RATES_LENGTH] memory feeRates = tradingFeeRates();

        uint256[] memory ids = new uint256[](FEE_RATES_LENGTH * 2);
        for (uint256 i; i < FEE_RATES_LENGTH; ) {
            ids[i] = _encodeId(feeRates[i], true);
            ids[i + FEE_RATES_LENGTH] = _encodeId(feeRates[i], false);

            unchecked {
                i++;
            }
        }

        return ids;
    }

    function _encodeId(uint16 tradingFeeRate, bool long) private pure returns (uint256 id) {
        id = long ? tradingFeeRate : tradingFeeRate + DIRECTION_PRECISION;
    }
}
