// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IMarketLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidity.sol";
import {IMarketLiquidityLens} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidityLens.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {MarketStorage, MarketStorageLib, LpReceiptStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MarketLiquidityFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacetBase.sol";

/**
 * @title MarketLiquidityLensFacet
 * @dev Contract for liquidity information retrieval in a market.
 */
contract MarketLiquidityLensFacet is MarketLiquidityFacetBase, IMarketLiquidityLens {
    /**
     * @inheritdoc IMarketLiquidityLens
     */
    function getBinLiquidity(int16 tradingFeeRate) external view override returns (uint256 amount) {
        amount = MarketStorageLib.marketStorage().liquidityPool.getBinLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLiquidityLens
     */
    function getBinFreeLiquidity(
        int16 tradingFeeRate
    ) external view override returns (uint256 amount) {
        amount = MarketStorageLib.marketStorage().liquidityPool.getBinFreeLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLiquidityLens
     */
    function getBinValues(
        int16[] memory tradingFeeRates
    ) external view override returns (uint256[] memory) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        LiquidityPool storage liquidityPool = ms.liquidityPool;

        LpContext memory ctx = newLpContext(ms);
        uint256[] memory values = new uint256[](tradingFeeRates.length);
        for (uint256 i; i < tradingFeeRates.length; ) {
            values[i] = liquidityPool.binValue(tradingFeeRates[i], ctx);

            unchecked {
                i++;
            }
        }
        return values;
    }

    /**
     * @inheritdoc IMarketLiquidityLens
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     */
    function getLpReceipt(uint256 receiptId) external view returns (LpReceipt memory receipt) {
        receipt = _getLpReceipt(LpReceiptStorageLib.lpReceiptStorage(), receiptId);
    }

    /**
     * @inheritdoc IMarketLiquidityLens
     */
    function pendingLiquidity(
        int16 tradingFeeRate
    ) external view returns (IMarketLiquidity.PendingLiquidity memory) {
        return MarketStorageLib.marketStorage().liquidityPool.pendingLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLiquidityLens
     */
    function pendingLiquidityBatch(
        int16[] calldata tradingFeeRates
    ) external view returns (IMarketLiquidity.PendingLiquidity[] memory) {
        IMarketLiquidity.PendingLiquidity[]
            memory liquidities = new IMarketLiquidity.PendingLiquidity[](tradingFeeRates.length);

        LiquidityPool storage pool = MarketStorageLib.marketStorage().liquidityPool;
        for (uint256 i; i < tradingFeeRates.length; ) {
            liquidities[i] = pool.pendingLiquidity(tradingFeeRates[i]);

            unchecked {
                i++;
            }
        }

        return liquidities;
    }

    /**
     * @inheritdoc IMarketLiquidityLens
     */
    function claimableLiquidity(
        int16 tradingFeeRate,
        uint256 oracleVersion
    ) external view returns (IMarketLiquidity.ClaimableLiquidity memory) {
        return
            MarketStorageLib.marketStorage().liquidityPool.claimableLiquidity(
                tradingFeeRate,
                oracleVersion
            );
    }

    /**
     * @inheritdoc IMarketLiquidityLens
     */
    function claimableLiquidityBatch(
        int16[] calldata tradingFeeRates,
        uint256 oracleVersion
    ) external view returns (IMarketLiquidity.ClaimableLiquidity[] memory) {
        IMarketLiquidity.ClaimableLiquidity[]
            memory liquidities = new IMarketLiquidity.ClaimableLiquidity[](tradingFeeRates.length);

        LiquidityPool storage pool = MarketStorageLib.marketStorage().liquidityPool;
        for (uint256 i; i < tradingFeeRates.length; ) {
            liquidities[i] = pool.claimableLiquidity(tradingFeeRates[i], oracleVersion);

            unchecked {
                i++;
            }
        }

        return liquidities;
    }

    /**
     * @inheritdoc IMarketLiquidityLens
     */
    function liquidityBinStatuses()
        external
        view
        returns (IMarketLiquidity.LiquidityBinStatus[] memory)
    {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        return ms.liquidityPool.liquidityBinStatuses(newLpContext(ms));
    }
}