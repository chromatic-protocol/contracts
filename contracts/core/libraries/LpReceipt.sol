// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {LpTokenLib} from "@usum/core/libraries/LpTokenLib.sol";

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
    int16 tradingFeeRate;
}

using LpReceiptLib for LpReceipt global;

library LpReceiptLib {
    function lpTokenId(LpReceipt memory self) internal pure returns (uint256) {
        return LpTokenLib.encodeId(self.tradingFeeRate);
    }
}
