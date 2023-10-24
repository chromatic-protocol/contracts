// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {PendingPosition, ClosingPosition, PendingLiquidity, ClaimableLiquidity, LiquidityBinStatus} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {IMarketLens} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLens.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {MarketStorage, MarketStorageLib, LpReceiptStorage, LpReceiptStorageLib, PositionStorage, PositionStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MarketLiquidityFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacetBase.sol";
import {MarketTradeFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeFacetBase.sol";

/**
 * @title MarketLensFacet
 * @dev Contract for liquidity information retrieval in a market.
 */
contract MarketLensFacet is MarketLiquidityFacetBase, MarketTradeFacetBase, IMarketLens {
    /**
     * @inheritdoc IMarketLens
     */
    function getBinLiquidity(int16 tradingFeeRate) external view override returns (uint256 amount) {
        amount = MarketStorageLib.marketStorage().liquidityPool.getBinLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLens
     */
    function getBinFreeLiquidity(
        int16 tradingFeeRate
    ) external view override returns (uint256 amount) {
        amount = MarketStorageLib.marketStorage().liquidityPool.getBinFreeLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLens
     */
    function getBinValues(
        int16[] memory tradingFeeRates
    ) external view override returns (uint256[] memory values) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        LiquidityPool storage liquidityPool = ms.liquidityPool;

        values = new uint256[](tradingFeeRates.length);
        LpContext memory ctx = newLpContext(ms);
        for (uint256 i; i < tradingFeeRates.length; ) {
            values[i] = liquidityPool.binValue(ctx, tradingFeeRates[i]);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @inheritdoc IMarketLens
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     */
    function getLpReceipt(uint256 receiptId) external view returns (LpReceipt memory receipt) {
        receipt = _getLpReceipt(LpReceiptStorageLib.lpReceiptStorage(), receiptId);
    }

    /**
     * @inheritdoc IMarketLens
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     */
    function getLpReceipts(
        uint256[] calldata receiptIds
    ) external view returns (LpReceipt[] memory receipts) {
        receipts = new LpReceipt[](receiptIds.length);
        LpReceiptStorage storage ls = LpReceiptStorageLib.lpReceiptStorage();
        for (uint256 i; i < receiptIds.length; ) {
            receipts[i] = _getLpReceipt(ls, receiptIds[i]);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @inheritdoc IMarketLens
     */
    function pendingLiquidity(
        int16 tradingFeeRate
    ) external view returns (PendingLiquidity memory liquidity) {
        liquidity = MarketStorageLib.marketStorage().liquidityPool.pendingLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLens
     */
    function pendingLiquidityBatch(
        int16[] calldata tradingFeeRates
    ) external view returns (PendingLiquidity[] memory liquidities) {
        liquidities = new PendingLiquidity[](tradingFeeRates.length);

        LiquidityPool storage pool = MarketStorageLib.marketStorage().liquidityPool;
        for (uint256 i; i < tradingFeeRates.length; ) {
            liquidities[i] = pool.pendingLiquidity(tradingFeeRates[i]);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @inheritdoc IMarketLens
     */
    function claimableLiquidity(
        int16 tradingFeeRate,
        uint256 oracleVersion
    ) external view returns (ClaimableLiquidity memory liquidity) {
        liquidity = MarketStorageLib.marketStorage().liquidityPool.claimableLiquidity(
            tradingFeeRate,
            oracleVersion
        );
    }

    /**
     * @inheritdoc IMarketLens
     */
    function claimableLiquidityBatch(
        int16[] calldata tradingFeeRates,
        uint256 oracleVersion
    ) external view returns (ClaimableLiquidity[] memory liquidities) {
        liquidities = new ClaimableLiquidity[](tradingFeeRates.length);

        LiquidityPool storage pool = MarketStorageLib.marketStorage().liquidityPool;
        for (uint256 i; i < tradingFeeRates.length; ) {
            liquidities[i] = pool.claimableLiquidity(tradingFeeRates[i], oracleVersion);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @inheritdoc IMarketLens
     */
    function liquidityBinStatuses() external view returns (LiquidityBinStatus[] memory statuses) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        statuses = ms.liquidityPool.liquidityBinStatuses(newLpContext(ms));
    }

    /**
     * @inheritdoc IMarketLens
     * @dev Throws a `NotExistPosition` error if the position does not exist.
     */
    function getPosition(uint256 positionId) external view returns (Position memory position) {
        position = _getPosition(PositionStorageLib.positionStorage(), positionId);
    }

    /**
     * @inheritdoc IMarketLens
     */
    function getPositions(
        uint256[] calldata positionIds
    ) external view returns (Position[] memory positions) {
        positions = new Position[](positionIds.length);
        PositionStorage storage ps = PositionStorageLib.positionStorage();
        for (uint i; i < positionIds.length; ) {
            positions[i] = _getPosition(ps, positionIds[i]);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @inheritdoc IMarketLens
     */
    function pendingPosition(
        int16 tradingFeeRate
    ) external view returns (PendingPosition memory position) {
        position = MarketStorageLib.marketStorage().liquidityPool.pendingPosition(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLens
     */
    function pendingPositionBatch(
        int16[] calldata tradingFeeRates
    ) external view returns (PendingPosition[] memory positions) {
        positions = new PendingPosition[](tradingFeeRates.length);

        LiquidityPool storage pool = MarketStorageLib.marketStorage().liquidityPool;
        for (uint256 i; i < tradingFeeRates.length; ) {
            positions[i] = pool.pendingPosition(tradingFeeRates[i]);

            unchecked {
                i++;
            }
        }
    }

    /**
     * @inheritdoc IMarketLens
     */
    function closingPosition(
        int16 tradingFeeRate
    ) external view returns (ClosingPosition memory position) {
        position = MarketStorageLib.marketStorage().liquidityPool.closingPosition(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLens
     */
    function closingPositionBatch(
        int16[] calldata tradingFeeRates
    ) external view returns (ClosingPosition[] memory positions) {
        positions = new ClosingPosition[](tradingFeeRates.length);

        LiquidityPool storage pool = MarketStorageLib.marketStorage().liquidityPool;
        for (uint256 i; i < tradingFeeRates.length; ) {
            positions[i] = pool.closingPosition(tradingFeeRates[i]);

            unchecked {
                i++;
            }
        }
    }
}
