// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {LpSlotKey, LpSlotKeyLib, Direction} from "@usum/core/libraries/LpSlotKey.sol";

contract LpSlotKeyTest is Test {
    function expectValidFee(uint128 fee, bool expectedValid) internal {
        bool isValid = LpSlotKeyLib
            .from(uint128(fee), Direction.Long)
            .validTradingFee();
        assertEq(isValid, expectedValid);
    }

    function testValidTradingFee() public {
        expectValidFee(0, false);
        expectValidFee(9, true);
        expectValidFee(10, true);
        expectValidFee(15, false);
        expectValidFee(30, true);
        expectValidFee(100, true);
        expectValidFee(150, false);
        expectValidFee(253, false);
        expectValidFee(300, true);
        expectValidFee(1000, true);
        expectValidFee(1100, false);
        expectValidFee(2340, false);
        expectValidFee(3500, true);
        expectValidFee(5000, true);
        expectValidFee(10000, false);
    }

    function test() public {
        uint128 tradingFee = 100;

        LpSlotKey long0100 = LpSlotKeyLib.from(tradingFee, Direction.Long);
        LpSlotKey short0100 = LpSlotKeyLib.from(tradingFee, Direction.Short);

        emit log_named_uint("long key", long0100.unwrap());
        emit log_named_uint("short key", short0100.unwrap());

        assertEq(long0100.unwrap(), uint256(tradingFee));
        assertEq(short0100.unwrap(), (1 << 128) + uint256(tradingFee));

        assertTrue(long0100.direction() == Direction.Long);
        assertTrue(short0100.direction() == Direction.Short);

        assertEq(long0100.tradingFee(), tradingFee);
        assertEq(short0100.tradingFee(), tradingFee);
    }
}
