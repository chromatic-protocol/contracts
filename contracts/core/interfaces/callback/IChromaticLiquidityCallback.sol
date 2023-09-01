// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IChromaticLiquidityCallback
 * @dev Interface for a contract that handles liquidity callbacks in the Chromatic protocol.
 *      Liquidity callbacks are used to handle various operations related to liquidity management.
 *      This interface defines the function signatures for different types of liquidity callbacks.
 */
interface IChromaticLiquidityCallback {
    /**
     * @notice Handles the callback after adding liquidity to the Chromatic protocol.
     * @param settlementToken The address of the settlement token used for adding liquidity.
     * @param vault The address of the vault where the liquidity is added.
     * @param data Additional data associated with the liquidity addition.
     */
    function addLiquidityCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external;

    /**
     * @notice Handles the callback after adding liquidity to the Chromatic protocol.
     * @param settlementToken The address of the settlement token used for adding liquidity.
     * @param vault The address of the vault where the liquidity is added.
     * @param data Additional data associated with the liquidity addition.
     */
    function addLiquidityBatchCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external;

    /**
     * @notice Handles the callback after claiming liquidity from the Chromatic protocol.
     * @param receiptId The ID of the liquidity claim receipt.
     * @param feeRate The trading fee rate associated with the liquidity claim.
     * @param depositedAmount The amount of liquidity deposited.
     * @param mintedCLBTokenAmount The amount of CLB tokens minted as liquidity.
     * @param data Additional data associated with the liquidity claim.
     */
    function claimLiquidityCallback(
        uint256 receiptId,
        int16 feeRate,
        uint256 depositedAmount,
        uint256 mintedCLBTokenAmount,
        bytes calldata data
    ) external;

    /**
     * @notice Handles the callback after claiming liquidity from the Chromatic protocol.
     * @param receiptIds The array of the liquidity receipt IDs.
     * @param feeRates The array of trading fee rates associated with each claim in the batch.
     * @param depositedAmounts The array of deposited liquidity amounts for each receipt in the batch.
     * @param mintedCLBTokenAmounts The array of CLB token amounts minted for each receipt in the batch.
     * @param data Additional data associated with the liquidity claim.
     */
    function claimLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        int16[] calldata feeRates,
        uint256[] calldata depositedAmounts,
        uint256[] calldata mintedCLBTokenAmounts,
        bytes calldata data
    ) external;

    /**
     * @notice Handles the callback after removing liquidity from the Chromatic protocol.
     * @param clbToken The address of the Chromatic liquidity token.
     * @param clbTokenId The ID of the Chromatic liquidity token to be removed.
     * @param data Additional data associated with the liquidity removal.
     */
    function removeLiquidityCallback(
        address clbToken,
        uint256 clbTokenId,
        bytes calldata data
    ) external;

    /**
     * @notice Handles the callback after removing liquidity from the Chromatic protocol.
     * @param clbToken The address of the Chromatic liquidity token.
     * @param clbTokenIds The array of the Chromatic liquidity token IDs to be removed.
     * @param data Additional data associated with the liquidity removal.
     */
    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata clbTokenIds,
        bytes calldata data
    ) external;

    /**
     * @notice Handles the callback after withdrawing liquidity from the Chromatic protocol.
     * @param receiptId The ID of the liquidity withdrawal receipt.
     * @param feeRate The trading fee rate associated with the liquidity withdrawal.
     * @param withdrawnAmount The amount of liquidity that has been withdrawn.
     * @param burnedCLBTokenAmount The amount of CLB tokens burned during the withdrawal.
     * @param data Additional data associated with the liquidity withdrawal.
     */
    function withdrawLiquidityCallback(
        uint256 receiptId,
        int16 feeRate,
        uint256 withdrawnAmount,
        uint256 burnedCLBTokenAmount,
        bytes calldata data
    ) external;

    /**
     * @notice Handles the callback after withdrawing liquidity from the Chromatic protocol.
     * @param receiptIds The array of the liquidity receipt IDs.
     * @param feeRates The array of trading fee rates associated with each withdrawal in the batch.
     * @param withdrawnAmounts The array of withdrawn liquidity amounts for each receipt in the batch.
     * @param burnedCLBTokenAmounts The array of CLB token amounts burned for each receipt in the batch.
     * @param data Additional data associated with the liquidity withdrawal.
     */
    function withdrawLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        int16[] calldata feeRates,
        uint256[] calldata withdrawnAmounts,
        uint256[] calldata burnedCLBTokenAmounts,
        bytes calldata data
    ) external;
}
