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

    function validTradingFee(LpSlotKey lpSlotKey) internal pure returns (bool) {
        uint128 fee = lpSlotKey.tradingFee();
        
        if (fee == 0 || fee > MAX_TRADING_FEE_RATE) return false;
        if (fee >= 1000) return fee % 500 == 0;
        if (fee >= 100) return fee % 100 == 0;
        if (fee >= 10) return fee % 10 == 0;

        return true;

        // while (fee > 0) {
        //     uint128 remainder = fee % 10;
        //     fee = fee / 10;
        //     if (fee == 0 || (fee < 10 && remainder == 0)) {
        //         return true;
        //     }
        // }

        // return false;
    }
}
