// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";

/**
 * @title IMarketLiquidity
 * @dev The interface for liquidity operations in a market.
 */
interface IMarketLiquidity {
    /**
     * @dev A struct representing pending liquidity information.
     * @param oracleVersion The oracle version of pending liqudity.
     * @param mintingTokenAmountRequested The amount of settlement tokens requested for minting.
     * @param burningCLBTokenAmountRequested The amount of CLB tokens requested for burning.
     */
    struct PendingLiquidity {
        uint256 oracleVersion;
        uint256 mintingTokenAmountRequested;
        uint256 burningCLBTokenAmountRequested;
    }

    /**
     * @dev A struct representing claimable liquidity information.
     * @param mintingTokenAmountRequested The amount of settlement tokens requested for minting.
     * @param mintingCLBTokenAmount The actual amount of CLB tokens minted.
     * @param burningCLBTokenAmountRequested The amount of CLB tokens requested for burning.
     * @param burningCLBTokenAmount The actual amount of CLB tokens burned.
     * @param burningTokenAmount The amount of settlement tokens equal in value to the burned CLB tokens.
     */
    struct ClaimableLiquidity {
        uint256 mintingTokenAmountRequested;
        uint256 mintingCLBTokenAmount;
        uint256 burningCLBTokenAmountRequested;
        uint256 burningCLBTokenAmount;
        uint256 burningTokenAmount;
    }

    /**
     * @dev A struct representing status of the liquidity bin.
     * @param liquidity The total liquidity amount in the bin
     * @param freeLiquidity The amount of free liquidity available in the bin.
     * @param binValue The current value of the bin.
     * @param tradingFeeRate The trading fee rate for the liquidity.
     */
    struct LiquidityBinStatus {
        uint256 liquidity;
        uint256 freeLiquidity;
        uint256 binValue;
        int16 tradingFeeRate;
    }

    /**
     * @dev A struct representing value of the liquidity bin.
     * @param binValue The value of liquidity bin expressed in amount of settlement token.
     * @param clbTokenTotalSupply The total supply amount of the CLB token.
     */
    struct LiquidityBinValue {
        uint256 binValue;
        uint256 clbTokenTotalSupply;
    }

    /**
     * @dev Emitted when liquidity is added to the market.
     * @param receipt The liquidity receipt.
     */
    event AddLiquidity(LpReceipt receipt);

    /**
     * @dev Emitted when liquidity is added to the market.
     * @param receipts An array of LP receipts.
     */
    event AddLiquidityBatch(LpReceipt[] receipts);

    /**
     * @dev Emitted when liquidity is claimed from the market.
     * @param clbTokenAmount The amount of CLB tokens claimed.
     * @param receipt The liquidity receipt.
     */
    event ClaimLiquidity(LpReceipt receipt, uint256 indexed clbTokenAmount);

    /**
     * @dev Emitted when liquidity is claimed from the market.
     * @param receipts An array of LP receipts.
     * @param clbTokenAmounts The amount list of CLB tokens claimed.
     */
    event ClaimLiquidityBatch(LpReceipt[] receipts, uint256[] clbTokenAmounts);

    /**
     * @dev Emitted when liquidity is removed from the market.
     * @param receipt The liquidity receipt.
     */
    event RemoveLiquidity(LpReceipt receipt);

    /**
     * @dev Emitted when liquidity is removed from the market.
     * @param receipts An array of LP receipts.
     */
    event RemoveLiquidityBatch(LpReceipt[] receipts);

    /**
     * @dev Emitted when liquidity is withdrawn from the market.
     * @param receipt The liquidity receipt.
     * @param amount The amount of liquidity withdrawn.
     * @param burnedCLBTokenAmount The amount of burned CLB tokens.
     */
    event WithdrawLiquidity(
        LpReceipt receipt,
        uint256 indexed amount,
        uint256 indexed burnedCLBTokenAmount
    );

    /**
     * @dev Emitted when liquidity is withdrawn from the market.
     * @param receipts An array of LP receipts.
     * @param amounts The amount list of liquidity withdrawn.
     * @param burnedCLBTokenAmounts The amount list of burned CLB tokens.
     */
    event WithdrawLiquidityBatch(
        LpReceipt[] receipts,
        uint256[] amounts,
        uint256[] burnedCLBTokenAmounts
    );

    /**
     * @dev Adds liquidity to the market.
     * @param recipient The address to receive the liquidity tokens.
     * @param tradingFeeRate The trading fee rate for the liquidity.
     * @param data Additional data for the liquidity callback.
     * @return The liquidity receipt.
     */
    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (LpReceipt memory);

    /**
     * @notice Adds liquidity to multiple liquidity bins of the market in a batch.
     * @param recipient The address of the recipient for each liquidity bin.
     * @param tradingFeeRates An array of fee rates for each liquidity bin.
     * @param amounts An array of amounts to add as liquidity for each bin.
     * @param data Additional data for the liquidity callback.
     * @return An array of LP receipts.
     */
    function addLiquidityBatch(
        address recipient,
        int16[] calldata tradingFeeRates,
        uint256[] calldata amounts,
        bytes calldata data
    ) external returns (LpReceipt[] memory);

    /**
     * @dev Claims liquidity from a liquidity receipt.
     * @param receiptId The ID of the liquidity receipt.
     * @param data Additional data for the liquidity callback.
     */
    function claimLiquidity(uint256 receiptId, bytes calldata data) external;

    /**
     * @dev Claims liquidity from a liquidity receipt.
     * @param receiptIds The array of the liquidity receipt IDs.
     * @param data Additional data for the liquidity callback.
     */
    function claimLiquidityBatch(uint256[] calldata receiptIds, bytes calldata data) external;

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

    /**
     * @dev Distributes earning to the liquidity bins.
     * @param earning The amount of earning to distribute.
     * @param marketBalance The balance of the market.
     */
    function distributeEarningToBins(uint256 earning, uint256 marketBalance) external;
}
