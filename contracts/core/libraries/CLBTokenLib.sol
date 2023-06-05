// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

uint256 constant DIRECTION_PRECISION = 10 ** 10;

/**
 * @title CLBTokenLib
 * @notice Provides utility functions for working with CLB tokens.
 */
library CLBTokenLib {
    using SignedMath for int256;
    using SafeCast for uint256;

    /**
     * @notice Encode the CLB token ID of ERC1155 token type
     * @dev If `tradingFeeRate` is negative, it adds `DIRECTION_PRECISION` to the absolute fee rate.
     *      Otherwise it returns the fee rate directly.
     * @return id The ID of ERC1155 token
     */
    function encodeId(int16 tradingFeeRate) internal pure returns (uint256 id) {
        uint256 absFeeRate = int256(tradingFeeRate).abs();
        id = tradingFeeRate < 0 ? absFeeRate + DIRECTION_PRECISION : absFeeRate;
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
}
