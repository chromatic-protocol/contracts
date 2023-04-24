// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

type LpSlotKey is uint256;
using LpSlotKeyLib for LpSlotKey global;

enum Direction {
    Long,
    Short
}

uint256 constant MAX_TRADING_FEE_RATE = 5000;

library LpSlotKeyLib {
    uint256 private constant DIRECTION_OFFSET = 128;

    function from(
        uint16 _tradingFeeRate,
        Direction _direction
    ) internal pure returns (LpSlotKey) {
        return
            LpSlotKey.wrap(
                (uint256(_direction) << DIRECTION_OFFSET) |
                    uint256(_tradingFeeRate)
            );
    }

    function unwrap(LpSlotKey self) internal pure returns (uint256) {
        return LpSlotKey.unwrap(self);
    }

    function direction(LpSlotKey self) internal pure returns (Direction) {
        return Direction(self.unwrap() >> DIRECTION_OFFSET);
    }

    function tradingFeeRate(LpSlotKey self) internal pure returns (uint16) {
        return uint16(self.unwrap());
    }

    function signedTradingFeeRate(
        LpSlotKey self
    ) internal pure returns (int16) {
        int8 sign = self.direction() == Direction.Long ? int8(1) : -1;
        return int16(self.tradingFeeRate()) * sign; // safe casting?
    }

    function eq(LpSlotKey self, LpSlotKey other) internal pure returns (bool) {
        return self.unwrap() == other.unwrap();
    }
}
