// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {LpReceipt} from "@chromatic/core/libraries/LpReceipt.sol";

/**
 * @title ILiquidity
 * @dev The interface for liquidity operations in a market.
 */
interface ILiquidity {
    error TooSmallAmount();
    error OnlyAccessableByVault();
    error NotExistLpReceipt();
    error InvalidLpReceiptAction();

    /**
     * @dev Emitted when liquidity is added to the market.
     * @param recipient The address to receive the CLB tokens.
     * @param receipt The liquidity receipt.
     */
    event AddLiquidity(address indexed recipient, LpReceipt receipt);

    /**
     * @dev Emitted when liquidity is claimed from the market.
     * @param recipient The address that receives the claimed CLB tokens.
     * @param clbTokenAmount The amount of CLB tokens claimed.
     * @param receipt The liquidity receipt.
     */
    event ClaimLiquidity(
        address indexed recipient,
        uint256 indexed clbTokenAmount,
        LpReceipt receipt
    );

    /**
     * @dev Emitted when liquidity is removed from the market.
     * @param recipient The address that receives the removed liquidity.
     * @param receipt The liquidity receipt.
     */
    event RemoveLiquidity(address indexed recipient, LpReceipt receipt);

    /**
     * @dev Emitted when liquidity is withdrawn from the market.
     * @param recipient The address that receives the withdrawn liquidity.
     * @param amount The amount of liquidity withdrawn.
     * @param burnedCLBTokenAmount The amount of burned CLB tokens.
     * @param receipt The liquidity receipt.
     */
    event WithdrawLiquidity(
        address indexed recipient,
        uint256 indexed amount,
        uint256 indexed burnedCLBTokenAmount,
        LpReceipt receipt
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
     * @dev Claims liquidity from a liquidity receipt.
     * @param receiptId The ID of the liquidity receipt.
     * @param data Additional data for the liquidity callback.
     */
    function claimLiquidity(uint256 receiptId, bytes calldata data) external;

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
     * @dev Withdraws liquidity from a liquidity receipt.
     * @param receiptId The ID of the liquidity receipt.
     * @param data Additional data for the liquidity callback.
     */
    function withdrawLiquidity(uint256 receiptId, bytes calldata data) external;

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
     * @dev Retrieves the value of a specific trading fee rate's bin in the liquidity pool.
     *      The value of a bin represents the total valuation of the liquidity in the bin.
     * @param tradingFeeRate The trading fee rate for which to retrieve the bin value.
     * @return value The value of the bin for the specified trading fee rate.
     */
    function getBinValue(int16 tradingFeeRate) external view returns (uint256 value);

    /**
     * @dev Distributes earning to the liquidity bins.
     * @param earning The amount of earning to distribute.
     * @param marketBalance The balance of the market.
     */
    function distributeEarningToBins(uint256 earning, uint256 marketBalance) external;

    /**
     * @dev Calculates the amount of CLB tokens to be minted for a given amount of liquidity and trading fee rate.
     *      The CLB token minting amount represents the number of CLB tokens that will be minted when providing liquidity.
     * @param tradingFeeRate The trading fee rate for which to calculate the CLB token minting.
     * @param amount The amount of liquidity for which to calculate the CLB token minting.
     * @return The amount of CLB tokens to be minted for the specified liquidity amount and trading fee rate.
     */
    function calculateCLBTokenMinting(
        int16 tradingFeeRate,
        uint256 amount
    ) external view returns (uint256);

    /**
     * @dev Calculates the value of CLB tokens for the given parameters.
     * @param tradingFeeRate The trading fee rate.
     * @param clbTokenAmount The amount of CLB tokens.
     * @return The value of CLB tokens.
     */
    function calculateCLBTokenValue(
        int16 tradingFeeRate,
        uint256 clbTokenAmount
    ) external view returns (uint256);

    /**
     * @dev Retrieves the liquidity receipt with the given receipt ID.
     *      It throws NotExistLpReceipt if the specified receipt ID does not exist.
     * @param receiptId The ID of the liquidity receipt to retrieve.
     * @return receipt The liquidity receipt with the specified ID.
     */
    function getLpReceipt(uint256 receiptId) external view returns (LpReceipt memory);

    /**
     * @dev Retrieves the claim burning details for a given liquidity receipt.
     * @param tradingFeeRate The trading fee rate for which to retrieve the claim burning details.
     * @param oracleVersion The oracle version for which to retrieve the claim burning details.
     * @return clbTokenAmount The total amount of CLB tokens waiting to be burned for the specified trading fee rate and oracle version.
     * @return burningAmount The amount of CLB tokens that can be claimed after being burnt for the specified trading fee rate and oracle version.
     * @return tokenAmount The corresponding amount of tokens obtained when claiming liquidity.
     */
    function getClaimBurning(
        int16 tradingFeeRate,
        uint256 oracleVersion
    ) external view returns (uint256 clbTokenAmount, uint256 burningAmount, uint256 tokenAmount);
}
