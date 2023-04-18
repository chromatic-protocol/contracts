// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

type LpSlotKey is uint256;
using LpSlotKeyLib for LpSlotKey global;

enum Direction {
    Long,
    Short
}

library LpSlotKeyLib {
    uint256 private constant DIRECTION_OFFSET = 128;

    function from(
        uint128 _tradingFee,
        Direction _direction
    ) internal pure returns (LpSlotKey) {
        return
            LpSlotKey.wrap(
                (uint256(_direction) << DIRECTION_OFFSET) | uint256(_tradingFee)
            );
    }

    function unwrap(LpSlotKey self) internal pure returns (uint256) {
        return LpSlotKey.unwrap(self);
    }

    function direction(LpSlotKey self) internal pure returns (Direction) {
        return Direction(self.unwrap() >> DIRECTION_OFFSET);
    }

    function tradingFee(LpSlotKey self) internal pure returns (uint128) {
        return uint128(self.unwrap());
    }

    function eq(LpSlotKey self, LpSlotKey other) internal pure returns (bool) {
        return self.unwrap() == other.unwrap();
    }
}
