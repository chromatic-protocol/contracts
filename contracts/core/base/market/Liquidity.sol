// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {ILiquidity} from "@chromatic/core/interfaces/market/ILiquidity.sol";
import {IChromaticLiquidityCallback} from "@chromatic/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {LpReceipt, LpAction} from "@chromatic/core/libraries/LpReceipt.sol";
import {MarketBase} from "@chromatic/core/base/market/MarketBase.sol";

/**
 * @title Liquidity
 * @dev Contract for managing liquidity in a market.
 */
abstract contract Liquidity is MarketBase, IERC1155Receiver {
    using Math for uint256;

    uint256 constant MINIMUM_LIQUIDITY = 10 ** 3;

    uint256 internal _lpReceiptId;

    /**
     * @dev Modifier to restrict a function to be called only by the vault contract.
     */
    modifier onlyVault() {
        if (msg.sender != address(vault)) revert OnlyAccessableByVault();
        _;
    }

    /**
     * @inheritdoc ILiquidity
     */
    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant returns (LpReceipt memory) {
        uint256 balanceBefore = settlementToken.balanceOf(address(vault));
        IChromaticLiquidityCallback(msg.sender).addLiquidityCallback(
            address(settlementToken),
            address(vault),
            data
        );

        uint256 amount = settlementToken.balanceOf(address(vault)) - balanceBefore;
        if (amount <= MINIMUM_LIQUIDITY) revert TooSmallAmount();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        vault.onAddLiquidity(amount);
        liquidityPool.acceptAddLiquidity(ctx, tradingFeeRate, amount);

        LpReceipt memory receipt = newLpReceipt(
            ctx,
            LpAction.ADD_LIQUIDITY,
            amount,
            recipient,
            tradingFeeRate
        );
        lpReceipts[receipt.id] = receipt;

        emit AddLiquidity(recipient, receipt);
        return receipt;
    }

    /**
     * @inheritdoc ILiquidity
     */
    function claimLiquidity(uint256 receiptId, bytes calldata data) external override nonReentrant {
        LpReceipt memory receipt = lpReceipts[receiptId];
        if (receipt.id == 0) revert NotExistLpReceipt();
        if (receipt.action != LpAction.ADD_LIQUIDITY) revert InvalidLpReceiptAction();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        uint256 clbTokenAmount = liquidityPool.acceptClaimLiquidity(
            ctx,
            receipt.tradingFeeRate,
            receipt.amount,
            receipt.oracleVersion
        );
        clbToken.safeTransferFrom(
            address(this),
            receipt.recipient,
            receipt.clbTokenId(),
            clbTokenAmount,
            bytes("")
        );

        IChromaticLiquidityCallback(msg.sender).claimLiquidityCallback(receipt.id, data);
        delete lpReceipts[receiptId];

        emit ClaimLiquidity(receipt.recipient, clbTokenAmount, receipt);
    }

    /**
     * @inheritdoc ILiquidity
     */
    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant returns (LpReceipt memory) {
        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        LpReceipt memory receipt = newLpReceipt(
            ctx,
            LpAction.REMOVE_LIQUIDITY,
            0,
            recipient,
            tradingFeeRate
        );

        uint256 clbTokenId = receipt.clbTokenId();
        uint256 balanceBefore = clbToken.balanceOf(address(this), clbTokenId);
        IChromaticLiquidityCallback(msg.sender).removeLiquidityCallback(
            address(clbToken),
            clbTokenId,
            data
        );

        uint256 clbTokenAmount = clbToken.balanceOf(address(this), clbTokenId) - balanceBefore;
        if (clbTokenAmount == 0) revert TooSmallAmount();

        liquidityPool.acceptRemoveLiquidity(ctx, tradingFeeRate, clbTokenAmount);
        receipt.amount = clbTokenAmount;

        lpReceipts[receipt.id] = receipt;
        emit RemoveLiquidity(recipient, receipt);
        return receipt;
    }

    /**
     * @inheritdoc ILiquidity
     */
    function withdrawLiquidity(
        uint256 receiptId,
        bytes calldata data
    ) external override nonReentrant {
        LpReceipt memory receipt = lpReceipts[receiptId];
        if (receipt.id == 0) revert NotExistLpReceipt();
        if (receipt.action != LpAction.REMOVE_LIQUIDITY) revert InvalidLpReceiptAction();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        address recipient = receipt.recipient;
        uint256 clbTokenAmount = receipt.amount;

        (uint256 amount, uint256 burnedCLBTokenAmount) = liquidityPool.acceptWithdrawLiquidity(
            ctx,
            receipt.tradingFeeRate,
            clbTokenAmount,
            receipt.oracleVersion
        );

        clbToken.safeTransferFrom(
            address(this),
            recipient,
            receipt.clbTokenId(),
            clbTokenAmount - burnedCLBTokenAmount,
            bytes("")
        );
        vault.onWithdrawLiquidity(recipient, amount);

        IChromaticLiquidityCallback(msg.sender).withdrawLiquidityCallback(receipt.id, data);
        delete lpReceipts[receiptId];

        emit WithdrawLiquidity(recipient, amount, burnedCLBTokenAmount, receipt);
    }

    /**
     * @inheritdoc ILiquidity
     */
    function getBinLiquidity(int16 tradingFeeRate) external view override returns (uint256 amount) {
        amount = liquidityPool.getBinLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc ILiquidity
     */
    function getBinFreeLiquidity(
        int16 tradingFeeRate
    ) external view override returns (uint256 amount) {
        amount = liquidityPool.getBinFreeLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc ILiquidity
     */
    function distributeEarningToBins(uint256 earning, uint256 marketBalance) external onlyVault {
        liquidityPool.distributeEarning(earning, marketBalance);
    }

    /**
     * @inheritdoc ILiquidity
     */
    function getBinValues(
        int16[] memory tradingFeeRates
    ) external view override returns (uint256[] memory) {
        LpContext memory ctx = newLpContext();
        uint256[] memory values = new uint256[](tradingFeeRates.length);
        for (uint256 i = 0; i < tradingFeeRates.length; i++) {
            values[i] = liquidityPool.binValue(tradingFeeRates[i], ctx);
        }
        return values;
    }

    /**
     * @inheritdoc ILiquidity
     */
    function getLpReceipt(uint256 receiptId) external view returns (LpReceipt memory receipt) {
        receipt = lpReceipts[receiptId];
        if (receipt.id == 0) revert NotExistLpReceipt();
    }

    /**
     * @inheritdoc ILiquidity
     */
    function claimableLiquidity(
        int16 tradingFeeRate,
        uint256 oracleVersion
    ) external view returns (ClaimableLiquidity memory) {
        return liquidityPool.claimableLiquidity(tradingFeeRate, oracleVersion);
    }

    /**
     * @dev Creates a new liquidity receipt.
     * @param ctx The liquidity context.
     * @param action The liquidity action.
     * @param amount The amount of liquidity.
     * @param recipient The address to receive the liquidity.
     * @param tradingFeeRate The trading fee rate for the liquidity.
     * @return The new liquidity receipt.
     */
    function newLpReceipt(
        LpContext memory ctx,
        LpAction action,
        uint256 amount,
        address recipient,
        int16 tradingFeeRate
    ) private returns (LpReceipt memory) {
        return
            LpReceipt({
                id: ++_lpReceiptId,
                oracleVersion: ctx.currentOracleVersion().version,
                action: action,
                amount: amount,
                recipient: recipient,
                tradingFeeRate: tradingFeeRate
            });
    }

    // implement IERC1155Receiver

    /**
     * @inheritdoc IERC1155Receiver
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @inheritdoc IERC1155Receiver
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.onERC1155Received.selector ^ this.onERC1155BatchReceived.selector; // IERC1155Receiver
    }
}
