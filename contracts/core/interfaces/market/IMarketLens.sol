// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {PendingPosition, ClosingPosition, PendingLiquidity, ClaimableLiquidity, LiquidityBinStatus} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";

/**
 * @title IMarketLens
 * @dev The interface for liquidity information retrieval in a market.
 */
interface IMarketLens {
    /**
     * @dev Retrieves the total liquidity amount for a specific trading fee rate in the liquidity pool.
     * @param tradingFeeRate The trading fee rate for which to retrieve the liquidity amount.
     * @return amount The total liquidity amount for the specified trading fee rate.
     */
    function getBinLiquidity(int16 tradingFeeRate) external view returns (uint256 amount);

    /**
     * @dev Retrieves the available (free) liquidity amount for a specific trading fee rate in the liquidity pool.
     * @param tradingFeeRate The trading fee rate for which to retrieve the available liquidity amount.
     * @return amount The available (free) liquidity amount for the specified trading fee rate.
     */
    function getBinFreeLiquidity(int16 tradingFeeRate) external view returns (uint256 amount);

    /**
     * @dev Retrieves the values of a specific trading fee rate's bins in the liquidity pool.
     *      The value of a bin represents the total valuation of the liquidity in the bin.
     * @param tradingFeeRates The list of trading fee rate for which to retrieve the bin value.
     * @return values The value list of the bins for the specified trading fee rates.
     */
    function getBinValues(
        int16[] calldata tradingFeeRates
    ) external view returns (uint256[] memory values);

    /**
     * @dev Retrieves the liquidity receipt with the given receipt ID.
     *      It throws NotExistLpReceipt if the specified receipt ID does not exist.
     * @param receiptId The ID of the liquidity receipt to retrieve.
     * @return receipt The liquidity receipt with the specified ID.
     */
    function getLpReceipt(uint256 receiptId) external view returns (LpReceipt memory);

    /**
     * @dev Retrieves the liquidity receipts with the given receipt IDs.
     *      It throws NotExistLpReceipt if the specified receipt ID does not exist.
     * @param receiptIds The ID list of the liquidity receipt to retrieve.
     * @return receipts The liquidity receipt list with the specified IDs.
     */
    function getLpReceipts(
        uint256[] calldata receiptIds
    ) external view returns (LpReceipt[] memory);

    /**
     * @dev Retrieves the pending liquidity information for a specific trading fee rate from the associated LiquidityPool.
     * @param tradingFeeRate The trading fee rate for which to retrieve the pending liquidity.
     * @return pendingLiquidity An instance of PendingLiquidity representing the pending liquidity information.
     */
    function pendingLiquidity(int16 tradingFeeRate) external view returns (PendingLiquidity memory);

    /**
     * @dev Retrieves the pending liquidity information for multiple trading fee rates from the associated LiquidityPool.
     * @param tradingFeeRates The list of trading fee rates for which to retrieve the pending liquidity.
     * @return pendingLiquidityBatch An array of PendingLiquidity instances representing the pending liquidity information for each trading fee rate.
     */
    function pendingLiquidityBatch(
        int16[] calldata tradingFeeRates
    ) external view returns (PendingLiquidity[] memory);

    /**
     * @dev Retrieves the claimable liquidity information for a specific trading fee rate and oracle version from the associated LiquidityPool.
     * @param tradingFeeRate The trading fee rate for which to retrieve the claimable liquidity.
     * @param oracleVersion The oracle version for which to retrieve the claimable liquidity.
     * @return claimableLiquidity An instance of ClaimableLiquidity representing the claimable liquidity information.
     */
    function claimableLiquidity(
        int16 tradingFeeRate,
        uint256 oracleVersion
    ) external view returns (ClaimableLiquidity memory);

    /**
     * @dev Retrieves the claimable liquidity information for multiple trading fee rates and a specific oracle version from the associated LiquidityPool.
     * @param tradingFeeRates The list of trading fee rates for which to retrieve the claimable liquidity.
     * @param oracleVersion The oracle version for which to retrieve the claimable liquidity.
     * @return claimableLiquidityBatch An array of ClaimableLiquidity instances representing the claimable liquidity information for each trading fee rate.
     */
    function claimableLiquidityBatch(
        int16[] calldata tradingFeeRates,
        uint256 oracleVersion
    ) external view returns (ClaimableLiquidity[] memory);

    /**
     * @dev Retrieves the liquidity bin statuses for the caller's liquidity pool.
     * @return statuses An array of LiquidityBinStatus representing the liquidity bin statuses.
     */
    function liquidityBinStatuses() external view returns (LiquidityBinStatus[] memory);

    /**
     * @dev Retrieves the position with the given position ID.
     *      It throws NotExistPosition if the specified position ID does not exist.
     * @param positionId The ID of the position to retrieve.
     * @return position The position with the specified ID.
     */
    function getPosition(uint256 positionId) external view returns (Position memory);

    /**
     * @dev Retrieves multiple positions by their IDs.
     * @param positionIds The IDs of the positions to retrieve.
     * @return positions An array of retrieved positions.
     */
    function getPositions(
        uint256[] calldata positionIds
    ) external view returns (Position[] memory positions);

    /**
     * @dev Retrieves the pending position information for a specific trading fee rate from the associated LiquidityPool.
     * @param tradingFeeRate The trading fee rate for which to retrieve the pending position.
     * @return pendingPosition An instance of PendingPosition representing the pending position information.
     */
    function pendingPosition(int16 tradingFeeRate) external view returns (PendingPosition memory);

    /**
     * @dev Retrieves the pending position information for multiple trading fee rates from the associated LiquidityPool.
     * @param tradingFeeRates The list of trading fee rates for which to retrieve the pending position.
     * @return pendingPositionBatch An array of PendingPosition instances representing the pending position information for each trading fee rate.
     */
    function pendingPositionBatch(
        int16[] calldata tradingFeeRates
    ) external view returns (PendingPosition[] memory);

    /**
     * @dev Retrieves the closing position information for a specific trading fee rate from the associated LiquidityPool.
     * @param tradingFeeRate The trading fee rate for which to retrieve the closing position.
     * @return closingPosition An instance of PendingPosition representing the closing position information.
     */
    function closingPosition(int16 tradingFeeRate) external view returns (ClosingPosition memory);

    /**
     * @dev Retrieves the closing position information for multiple trading fee rates from the associated LiquidityPool.
     * @param tradingFeeRates The list of trading fee rates for which to retrieve the closing position.
     * @return pendingPositionBatch An array of PendingPosition instances representing the closing position information for each trading fee rate.
     */
    function closingPositionBatch(
        int16[] calldata tradingFeeRates
    ) external view returns (ClosingPosition[] memory);
}
