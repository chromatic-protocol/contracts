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
     * @dev Retrieves the bin liquidities for the given trading fee rates.
     * @param tradingFeeRates The trading fee rates to retrieve bin liquidities for.
     * @return amounts An array of bin liquidities corresponding to the trading fee rates.
     */
    function getBinLiquidities(
        int16[] memory tradingFeeRates
    ) external returns (uint256[] memory amounts);

    /**
     * @dev Retrieves the bin free liquidities for the given trading fee rates.
     * @param tradingFeeRates The trading fee rates to retrieve bin free liquidities for.
     * @return amounts An array of bin free liquidities corresponding to the trading fee rates.
     */
    function getBinFreeLiquidities(
        int16[] memory tradingFeeRates
    ) external returns (uint256[] memory amounts);

    /**
     * @dev Distributes earning to the liquidity bins.
     * @param earning The amount of earning to distribute.
     * @param marketBalance The balance of the market.
     */
    function distributeEarningToBins(uint256 earning, uint256 marketBalance) external;

    /**
     * @dev Calculates the amount of CLB tokens to mint for the given parameters.
     * @param tradingFeeRate The trading fee rate.
     * @param amount The amount of liquidity.
     * @return The amount of CLB tokens to mint.
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
}
