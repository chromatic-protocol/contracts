// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
// import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Position} from "@usum/core/libraries/Position.sol";
// import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotSet} from "@usum/core/libraries/LpSlotSet.sol";

// import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
// import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";

contract LpSlotSetTest is Test {
    LpSlotSet slotSet;

    function testPrepareSlotMargins() public {
        Position memory position;
        slotSet.prepareSlotMargins(position, 0);
    }
}
