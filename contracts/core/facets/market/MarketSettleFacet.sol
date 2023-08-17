// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IMarketSettle} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketSettle.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {MarketStorage, MarketStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MarketFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketFacetBase.sol";

/**
 * @title MarketSettleFacet
 */
contract MarketSettleFacet is MarketFacetBase, IMarketSettle {
    /**
     * @inheritdoc IMarketSettle
     * @dev This function settles the market by synchronizing the oracle version
     *      and calling the settle function of the liquidity pool.
     */
    function settle(int16[] calldata feeRates) external override {
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        ms.liquidityPool.settle(ctx, feeRates);
    }

    /**
     * @inheritdoc IMarketSettle
     * @dev This function settles the market by synchronizing the oracle version
     *      and calling the settle function of the liquidity pool.
     */
    function settleAll() external override {
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        ms.liquidityPool.settleAll(ctx);
    }
}
