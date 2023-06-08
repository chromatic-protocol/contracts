// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLiquidityCallback} from "@chromatic/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {Position} from "@chromatic/core/libraries/Position.sol";
import {LpReceipt} from "@chromatic/core/libraries/LpReceipt.sol";

/**
 * @title IChromaticRouter
 * @dev Interface for the ChromaticRouter contract.
 */
interface IChromaticRouter is IChromaticLiquidityCallback {
    /**
     * @dev Opens a new position in a ChromaticMarket contract.
     * @param market The address of the ChromaticMarket contract.
     * @param qty The quantity of the position.
     * @param leverage The leverage of the position.
     * @param takerMargin The margin amount for the taker.
     * @param makerMargin The margin amount for the maker.
     * @param maxAllowableTradingFee The maximum allowable trading fee.
     * @return position The new position.
     */
    function openPosition(
        address market,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external returns (Position memory);

    /**
     * @notice Closes a position in a ChromaticMarket contract.
     * @param market The address of the ChromaticMarket contract.
     * @param positionId The ID of the position to close.
     */
    function closePosition(address market, uint256 positionId) external;

    /**
     * @notice Claims a position from a ChromaticMarket contract.
     * @param market The address of the ChromaticMarket contract.
     * @param positionId The ID of the position to claim.
     */
    function claimPosition(address market, uint256 positionId) external;

    /**
     * @notice Adds liquidity to a ChromaticMarket contract.
     * @param market The address of the ChromaticMarket contract.
     * @param feeRate The fee rate of the liquidity bin.
     * @param amount The amount to add as liquidity.
     * @param recipient The recipient address.
     * @return receipt The LP receipt.
     */
    function addLiquidity(
        address market,
        int16 feeRate,
        uint256 amount,
        address recipient
    ) external returns (LpReceipt memory);

    /**
     * @notice Claims liquidity from a ChromaticMarket contract.
     * @param market The address of the ChromaticMarket contract.
     * @param receiptId The ID of the LP receipt.
     */
    function claimLiquidity(address market, uint256 receiptId) external;

    /**
     * @notice Removes liquidity from a ChromaticMarket contract.
     * @param market The address of the ChromaticMarket contract.
     * @param feeRate The fee rate of the liquidity bin.
     * @param clbTokenAmount The amount of CLB tokens to remove as liquidity.
     * @param recipient The recipient address.
     * @return receipt The LP receipt.
     */
    function removeLiquidity(
        address market,
        int16 feeRate,
        uint256 clbTokenAmount,
        address recipient
    ) external returns (LpReceipt memory);

    /**
     * @notice Withdraws liquidity from a ChromaticMarket contract.
     * @param market The address of the ChromaticMarket contract.
     * @param receiptId The ID of the LP receipt.
     */
    function withdrawLiquidity(address market, uint256 receiptId) external;

    /**
     * @notice Retrieves the account of the caller.
     * @return The account address.
     */
    function getAccount() external view returns (address);

    /**
     * @notice Retrieves the LP receipt IDs of the caller for the specified market.
     * @param market The address of the ChromaticMarket contract.
     * @return An array of LP receipt IDs.
     */
    function getLpReceiptIds(address market) external view returns (uint256[] memory);

    /**
     * @notice Adds liquidity to multiple ChromaticMarket contracts in a batch.
     * @param market The address of the ChromaticMarket contract.
     * @param feeRates An array of fee rates for each liquidity bin.
     * @param amounts An array of amounts to add as liquidity for each bin.
     * @param recipients An array of recipient addresses.
     * @return lpReceipts An array of LP receipts.
     */
    function addLiquidityBatch(
        address market,
        int16[] calldata feeRates,
        uint256[] calldata amounts,
        address[] calldata recipients
    ) external returns (LpReceipt[] memory lpReceipts);

    /**
     * @notice Claims liquidity from multiple ChromaticMarket contracts in a batch.
     * @param market The address of the ChromaticMarket contract.
     * @param receiptIds An array of LP receipt IDs to claim liquidity from.
     */
    function claimLiquidityBatch(address market, uint256[] calldata receiptIds) external;

    /**
     * @notice Removes liquidity from multiple ChromaticMarket contracts in a batch.
     * @param market The address of the ChromaticMarket contract.
     * @param feeRates An array of fee rates for each liquidity bin.
     * @param clbTokenAmounts An array of CLB token amounts to remove as liquidity for each bin.
     * @param recipients An array of recipient addresses.
     * @return lpReceipts An array of LP receipts.
     */
    function removeLiquidityBatch(
        address market,
        int16[] calldata feeRates,
        uint256[] calldata clbTokenAmounts,
        address[] calldata recipients
    ) external returns (LpReceipt[] memory lpReceipts);

    /**
     * @notice Withdraws liquidity from multiple ChromaticMarket contracts in a batch.
     * @param market The address of the ChromaticMarket contract.
     * @param receiptIds An array of LP receipt IDs to withdraw liquidity from.
     */
    function withdrawLiquidityBatch(address market, uint256[] calldata receiptIds) external;

    /**
     * @notice Calculates the value of CLB tokens for multiple liquidity amounts in a batch.
     * @param market The address of the ChromaticMarket contract.
     * @param tradingFeeRates An array of trading fee rates for each liquidity provider.
     * @param clbTokenAmounts An array of CLB token amounts for each provider.
     * @return results An array of CLB token values.
     */
    function calculateCLBTokenValueBatch(
        address market,
        int16[] calldata tradingFeeRates,
        uint256[] calldata clbTokenAmounts
    ) external view returns (uint256[] memory results);

    /**
     * @notice Calculates the amount of CLB tokens to mint for multiple trading amounts in a batch.
     * @param market The address of the ChromaticMarket contract.
     * @param tradingFeeRates An array of trading fee rates for each liquidity provider.
     * @param amounts An array of trading amounts for each provider.
     * @return results An array of CLB token minting amounts.
     */
    function calculateCLBTokenMintingBatch(
        address market,
        int16[] calldata tradingFeeRates,
        uint256[] calldata amounts
    ) external view returns (uint256[] memory results);

    /**
     * @notice Retrieves the total supplies of CLB tokens for multiple trading fee rates in a batch.
     * @param market The address of the ChromaticMarket contract.
     * @param tradingFeeRates An array of trading fee rates to retrieve total supplies for.
     * @return supplies An array of total CLB token supplies.
     */
    function totalSupplies(
        address market,
        int16[] calldata tradingFeeRates
    ) external view returns (uint256[] memory supplies);
}
