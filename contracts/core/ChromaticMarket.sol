// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";
import {Liquidity} from "@chromatic/core/base/market/Liquidity.sol";
import {Trade} from "@chromatic/core/base/market/Trade.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";

/**
 * @title ChromaticMarket
 * @dev A contract that represents a Chromatic market, combining trade and liquidity functionalities.
 */
contract ChromaticMarket is Trade, Liquidity {
    /**
     * @inheritdoc IChromaticMarket
     * @dev This function settles the market by synchronizing the oracle version
     *      and calling the settle function of the liquidity pool.
     */
    function settle() external override {
        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();
        liquidityPool.settle(ctx);
    }
}
