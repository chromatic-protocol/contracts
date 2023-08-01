// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {PositionUtil} from "@chromatic-protocol/contracts/core/libraries/PositionUtil.sol";

contract PositionUtilTest is Test {
    function testPnl() public {
        int256 longProfit = PositionUtil.pnl(50, 100, 110);
        assertEq(longProfit, 5);

        int256 longLoss = PositionUtil.pnl(50, 100, 90);
        assertEq(longLoss, -5);

        int256 shortProfit = PositionUtil.pnl(-50, 100, 90);
        assertEq(shortProfit, 5);

        int256 shortLoss = PositionUtil.pnl(-50, 100, 110);
        assertEq(shortLoss, -5);
    }
}
