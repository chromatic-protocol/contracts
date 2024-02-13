// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "forge-std/console2.sol";

contract TestArea is Test {
    function testCast() public {
        // uint80 roundId = 0x5000000001CDAAC04;
        uint80 roundId = 92233720369031851012;
        // 0x5000000000000AC04 92233720368547802116
        emit log_named_uint("full", roundId);
        emit log_named_uint("casting", uint64(roundId));
        assertEq(uint64(roundId), uint64(0x1CDAAC04));
    }
}
