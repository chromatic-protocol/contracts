// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {OpenPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTradeOpenPosition.sol";

/**
 * @title IChromaticRouter
 * @dev Interface for the ChromaticRouter contract.
 */
interface IChromaticRouter is IChromaticLiquidityCallback {
    /**
     * @dev Emitted when a position is opened.
     * @param marketAddress The address of the market.
     * @param trader The owner of The account
     * @param account The account The address of the account opening the position.
     * @param tradingFee The trading fee associated with the position.
     * @param tradingFeeUSD The trading fee in USD
     */
    event OpenPosition(
        address indexed marketAddress,
        address indexed trader,
        address indexed account,
        uint256 tradingFee,
        uint256 tradingFeeUSD
    );

    /**
     * @dev Emitted when a new account is created.
     * @param account The address of the created account.
     * @param owner The address of the owner of the created account.
     */
    event AccountCreated(address indexed account, address indexed owner);

    /**
     * @dev Opens a new position in a ChromaticMarket contract.
     * @param market The address of the ChromaticMarket contract.
     * @param qty The quantity of the position.
     * @param takerMargin The margin amount for the taker.
     * @param makerMargin The margin amount for the maker.
     * @param maxAllowableTradingFee The maximum allowable trading fee.
     * @return position The new position.
     */
    function openPosition(
        address market,
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external returns (OpenPositionInfo memory);

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
     * @notice Creates a new user account.
     * @dev Only one account can be created per user.
     *      Emits an `AccountCreated` event upon successful creation.
     */
    function createAccount() external;

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
     * @notice Get the LP receipt IDs associated with a specific market and owner.
     * @param market The address of the ChromaticMarket contract.
     * @param owner The address of the owner.
     * @return An array of LP receipt IDs.
     */
    function getLpReceiptIds(
        address market,
        address owner
    ) external view returns (uint256[] memory);

    /**
     * @notice Adds liquidity to multiple liquidity bins of ChromaticMarket contract in a batch.
     * @param market The address of the ChromaticMarket contract.
     * @param recipient The address of the recipient for each liquidity bin.
     * @param feeRates An array of fee rates for each liquidity bin.
     * @param amounts An array of amounts to add as liquidity for each bin.
     * @return lpReceipts An array of LP receipts.
     */
    function addLiquidityBatch(
        address market,
        address recipient,
        int16[] calldata feeRates,
        uint256[] calldata amounts
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
     * @param recipient The address of the recipient for each liquidity bin.
     * @param feeRates An array of fee rates for each liquidity bin.
     * @param clbTokenAmounts An array of CLB token amounts to remove as liquidity for each bin.
     * @return lpReceipts An array of LP receipts.
     */
    function removeLiquidityBatch(
        address market,
        address recipient,
        int16[] calldata feeRates,
        uint256[] calldata clbTokenAmounts
    ) external returns (LpReceipt[] memory lpReceipts);

    /**
     * @notice Withdraws liquidity from multiple ChromaticMarket contracts in a batch.
     * @param market The address of the ChromaticMarket contract.
     * @param receiptIds An array of LP receipt IDs to withdraw liquidity from.
     */
    function withdrawLiquidityBatch(address market, uint256[] calldata receiptIds) external;
}
