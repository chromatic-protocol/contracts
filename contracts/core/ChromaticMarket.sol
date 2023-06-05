// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Liquidity} from "@chromatic/core/base/market/Liquidity.sol";
import {Trade} from "@chromatic/core/base/market/Trade.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";

contract ChromaticMarket is Trade, Liquidity {
    function settle() external override {
        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();
        liquidityPool.settle(ctx);
    }
}
