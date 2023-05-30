// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

enum LpAction {
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY
}

struct LpReceipt {
    uint256 id;
    uint256 oracleVersion;
    uint256 amount;
    address recipient;
    LpAction action;
}
