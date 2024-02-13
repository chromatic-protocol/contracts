// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";

/**
 * @title IMarketRemoveLiquidity
 * @dev The interface for removing and withdrawing liquidity in a market.
 */
interface IMarketRemoveLiquidity {
    /**
     * @dev Removes liquidity from the market.
     * @param recipient The address to receive the removed liquidity.
     * @param tradingFeeRate The trading fee rate for the liquidity.
     * @param data Additional data for the liquidity callback.
     * @return The liquidity receipt.
     */
    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (LpReceipt memory);

    /**
     * @dev Removes liquidity from the market.
     * @param recipient The address to receive the removed liquidity.
     * @param tradingFeeRates An array of fee rates for each liquidity bin.
     * @param clbTokenAmounts An array of clb token amounts to remove as liquidity for each bin.
     * @param data Additional data for the liquidity callback.
     * @return The liquidity receipt.
     */
    function removeLiquidityBatch(
        address recipient,
        int16[] calldata tradingFeeRates,
        uint256[] calldata clbTokenAmounts,
        bytes calldata data
    ) external returns (LpReceipt[] memory);

    /**
     * @dev Withdraws liquidity from a liquidity receipt.
     * @param receiptId The ID of the liquidity receipt.
     * @param data Additional data for the liquidity callback.
     */
    function withdrawLiquidity(uint256 receiptId, bytes calldata data) external;

    /**
     * @dev Withdraws liquidity from a liquidity receipt.
     * @param receiptIds The array of the liquidity receipt IDs.
     * @param data Additional data for the liquidity callback.
     */
    function withdrawLiquidityBatch(uint256[] calldata receiptIds, bytes calldata data) external;
}
