// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IMarketErrors
 */
interface IMarketErrors {
    /**
     * @dev Throws an error indicating that the caller is not the DAO.
     */
    error OnlyAccessableByDao();

    /**
     * @dev Throws an error indicating that the caller is nether the chormatic factory contract nor the DAO.
     */
    error OnlyAccessableByFactoryOrDao();

    /**
     * @dev Throws an error indicating that the caller is not the chromatic liquidator contract.
     */

    error OnlyAccessableByLiquidator();

    /**
     * @dev Throws an error indicating that the caller is not the chromatch vault contract.
     */
    error OnlyAccessableByVault();

    /**
     * @dev Throws an error indicating that the amount of liquidity is too small.
     *      This error is thrown when attempting to remove liquidity with an amount of zero.
     */
    error TooSmallAmount();

    /**
     * @dev Throws an error indicating that the specified liquidity receipt does not exist.
     */
    error NotExistLpReceipt();

    /**
     * @dev Throws an error indicating that the liquidity receipt is not claimable.
     */
    error NotClaimableLpReceipt();

    /**
     * @dev Throws an error indicating that the liquidity receipt is not withdrawable.
     */
    error NotWithdrawableLpReceipt();

    /**
     * @dev Throws an error indicating that the liquidity receipt action is invalid.
     */
    error InvalidLpReceiptAction();

    /**
     * @dev Throws an error indicating that the transferred token amount is invalid.
     *      This error is thrown when the transferred token amount does not match the expected amount.
     */
    error InvalidTransferredTokenAmount();

    error DuplicatedTradingFeeRate();

    error AddLiquidityDisabled();
    error RemoveLiquidityDisabled();

    /**
     * @dev Throws an error indicating that the taker margin provided is smaller than the minimum required margin for the specific settlement token.
     *      The minimum required margin is determined by the DAO and represents the minimum amount required for operations such as liquidation and payment of keeper fees.
     */
    error TooSmallTakerMargin();

    /**
     * @dev Throws an error indicating that the margin settlement token balance does not increase by the required margin amount after the callback.
     */
    error NotEnoughMarginTransferred();

    /**
     * @dev Throws an error indicating that the caller is not permitted to perform the action as they are not the owner of the position.
     */
    error NotPermitted();

    /**
     * @dev Throws an error indicating that the total trading fee (including protocol fee) exceeds the maximum allowable trading fee.
     */
    error ExceedMaxAllowableTradingFee();

    /**
     * @dev Throws an error indicating thatwhen the specified leverage exceeds the maximum allowable leverage level set by the Oracle Provider.
     *      Each Oracle Provider has a specific maximum allowable leverage level, which is determined by the DAO.
     *      The default maximum allowable leverage level is 0, which corresponds to a leverage of up to 10x.
     */
    error ExceedMaxAllowableLeverage();

    /**
     * @dev Throws an error indicating that the maker margin value is not within the allowable range based on the absolute quantity and the specified minimum/maximum take-profit basis points (BPS).
     *      The maker margin must fall within the range calculated based on the absolute quantity of the position and the specified minimum/maximum take-profit basis points (BPS) set by the Oracle Provider.
     *      The default range for the minimum/maximum take-profit basis points is 10% to 1000%.
     */
    error NotAllowableMakerMargin();

    /**
     * @dev Throws an error indicating that the requested position does not exist.
     */
    error NotExistPosition();

    /**
     * @dev Throws an error indicating that an error occurred during the claim position callback.
     */
    error ClaimPositionCallbackError();

    /**
     * @dev Throws an error indicating that the position has already been closed.
     */
    error AlreadyClosedPosition();

    /**
     *@dev Throws an error indicating that the position is not claimable.
     */
    error NotClaimablePosition();

    error OpenPositionDisabled();
    error ClosePositionDisabled();
}
