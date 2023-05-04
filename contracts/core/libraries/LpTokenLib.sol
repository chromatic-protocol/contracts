// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

uint256 constant DIRECTION_PRECISION = 10 ** 10;

library LpTokenLib {

    using SignedMath for int256;
    using SafeCast for uint256;

    function encodeId(int16 tradingFeeRate) internal pure returns (uint256 id) {
        uint256 absFeeRate = int256(tradingFeeRate).abs();
        id = tradingFeeRate < 0 ? absFeeRate + DIRECTION_PRECISION : absFeeRate;
    }

    function decodeId(uint256 id) internal pure returns (int16 tradingFeeRate) {
        if (id >= DIRECTION_PRECISION) {
            tradingFeeRate = -int16((id - DIRECTION_PRECISION).toUint16());
        } else {
            tradingFeeRate = int16(id.toUint16());
        }
    }
}
