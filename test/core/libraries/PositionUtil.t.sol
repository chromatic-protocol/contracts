// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {PositionUtil, LEVERAGED_QTY_PRECISION} from "@usum/core/libraries/PositionUtil.sol";

contract PositionUtilTest is Test {
    function testPnl() public {
        int256 longProfit = PositionUtil.pnl(
            50,
            100,
            110,
            LEVERAGED_QTY_PRECISION
        );
        assertEq(longProfit, 5);

        int256 longLoss = PositionUtil.pnl(
            50,
            100,
            90,
            LEVERAGED_QTY_PRECISION
        );
        assertEq(longLoss, -5);

        int256 shortProfit = PositionUtil.pnl(
            -50,
            100,
            90,
            LEVERAGED_QTY_PRECISION
        );
        assertEq(shortProfit, 5);

        int256 shortLoss = PositionUtil.pnl(
            -50,
            100,
            110,
            LEVERAGED_QTY_PRECISION
        );
        assertEq(shortLoss, -5);
    }
}
