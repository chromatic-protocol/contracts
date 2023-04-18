// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LpSlotKey} from "@usum/core/libraries/LpSlotKey.sol";

struct LpSlotMargin {
    LpSlotKey key;
    uint256 amount;
}
