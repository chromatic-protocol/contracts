// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {IVault} from "@chromatic-protocol/contracts/core/interfaces/vault/IVault.sol";
import {IMarketLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidity.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {LpReceipt, LpAction} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {MarketStorage, MarketStorageLib, LpReceiptStorage, LpReceiptStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MINIMUM_LIQUIDITY} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {MarketFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketFacetBase.sol";

/**
 * @title MarketLiquidityFacet
 * @dev Contract for managing liquidity in a market.
 */
contract MarketLiquidityFacet is MarketFacetBase, IMarketLiquidity, IERC1155Receiver, ReentrancyGuard {
    using Math for uint256;

    error TooSmallAmount();
    error NotExistLpReceipt();
    error NotClaimableLpReceipt();
    error NotWithdrawableLpReceipt();
    error InvalidLpReceiptAction();

    /**
     * @inheritdoc IMarketLiquidity
     */
    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant returns (LpReceipt memory) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        IERC20Metadata settlementToken = ms.settlementToken;
        IVault vault = ms.vault;

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
        ms.liquidityPool.acceptAddLiquidity(ctx, tradingFeeRate, amount);

        LpReceipt memory receipt = _newLpReceipt(
            ctx,
            LpAction.ADD_LIQUIDITY,
            amount,
            recipient,
            tradingFeeRate
        );
        LpReceiptStorageLib.lpReceiptStorage().setReceipt(receipt);

        emit AddLiquidity(recipient, receipt);
        return receipt;
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function claimLiquidity(uint256 receiptId, bytes calldata data) external override nonReentrant {
        LpReceiptStorage storage ls = LpReceiptStorageLib.lpReceiptStorage();

        LpReceipt memory receipt = _getLpReceipt(ls, receiptId);
        if (receipt.action != LpAction.ADD_LIQUIDITY) revert InvalidLpReceiptAction();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        if (!ctx.isPastVersion(receipt.oracleVersion)) revert NotClaimableLpReceipt();

        MarketStorage storage ms = MarketStorageLib.marketStorage();
        uint256 clbTokenAmount = ms.liquidityPool.acceptClaimLiquidity(
            ctx,
            receipt.tradingFeeRate,
            receipt.amount,
            receipt.oracleVersion
        );
        ms.clbToken.safeTransferFrom(
            address(this),
            receipt.recipient,
            receipt.clbTokenId(),
            clbTokenAmount,
            bytes("")
        );

        IChromaticLiquidityCallback(msg.sender).claimLiquidityCallback(receipt.id, data);
        ls.deleteReceipt(receiptId);

        emit ClaimLiquidity(receipt.recipient, clbTokenAmount, receipt);
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant returns (LpReceipt memory) {
        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        LpReceipt memory receipt = _newLpReceipt(
            ctx,
            LpAction.REMOVE_LIQUIDITY,
            0,
            recipient,
            tradingFeeRate
        );

        MarketStorage storage ms = MarketStorageLib.marketStorage();
        ICLBToken clbToken = ms.clbToken;

        uint256 clbTokenId = receipt.clbTokenId();
        uint256 balanceBefore = clbToken.balanceOf(address(this), clbTokenId);
        IChromaticLiquidityCallback(msg.sender).removeLiquidityCallback(
            address(clbToken),
            clbTokenId,
            data
        );

        uint256 clbTokenAmount = clbToken.balanceOf(address(this), clbTokenId) - balanceBefore;
        if (clbTokenAmount == 0) revert TooSmallAmount();

        ms.liquidityPool.acceptRemoveLiquidity(ctx, tradingFeeRate, clbTokenAmount);
        receipt.amount = clbTokenAmount;

        LpReceiptStorageLib.lpReceiptStorage().setReceipt(receipt);
        emit RemoveLiquidity(recipient, receipt);
        return receipt;
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function withdrawLiquidity(
        uint256 receiptId,
        bytes calldata data
    ) external override nonReentrant {
        LpReceiptStorage storage ls = LpReceiptStorageLib.lpReceiptStorage();

        LpReceipt memory receipt = _getLpReceipt(ls, receiptId);
        if (receipt.action != LpAction.REMOVE_LIQUIDITY) revert InvalidLpReceiptAction();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        if (!ctx.isPastVersion(receipt.oracleVersion)) revert NotWithdrawableLpReceipt();

        address recipient = receipt.recipient;
        uint256 clbTokenAmount = receipt.amount;

        MarketStorage storage ms = MarketStorageLib.marketStorage();

        (uint256 amount, uint256 burnedCLBTokenAmount) = ms.liquidityPool.acceptWithdrawLiquidity(
            ctx,
            receipt.tradingFeeRate,
            clbTokenAmount,
            receipt.oracleVersion
        );

        ms.clbToken.safeTransferFrom(
            address(this),
            recipient,
            receipt.clbTokenId(),
            clbTokenAmount - burnedCLBTokenAmount,
            bytes("")
        );
        ms.vault.onWithdrawLiquidity(recipient, amount);

        IChromaticLiquidityCallback(msg.sender).withdrawLiquidityCallback(receipt.id, data);
        ls.deleteReceipt(receiptId);

        emit WithdrawLiquidity(recipient, amount, burnedCLBTokenAmount, receipt);
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function getBinLiquidity(int16 tradingFeeRate) external view override returns (uint256 amount) {
        amount = MarketStorageLib.marketStorage().liquidityPool.getBinLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function getBinFreeLiquidity(
        int16 tradingFeeRate
    ) external view override returns (uint256 amount) {
        amount = MarketStorageLib.marketStorage().liquidityPool.getBinFreeLiquidity(tradingFeeRate);
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function distributeEarningToBins(uint256 earning, uint256 marketBalance) external onlyVault {
        MarketStorageLib.marketStorage().liquidityPool.distributeEarning(earning, marketBalance);
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function getBinValues(
        int16[] memory tradingFeeRates
    ) external view override returns (uint256[] memory) {
        LiquidityPool storage liquidityPool = MarketStorageLib.marketStorage().liquidityPool;

        LpContext memory ctx = newLpContext();
        uint256[] memory values = new uint256[](tradingFeeRates.length);
        for (uint256 i; i < tradingFeeRates.length; ) {
            values[i] = liquidityPool.binValue(tradingFeeRates[i], ctx);

            unchecked {
                i++;
            }
        }
        return values;
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function getLpReceipt(uint256 receiptId) external view returns (LpReceipt memory receipt) {
        receipt = _getLpReceipt(LpReceiptStorageLib.lpReceiptStorage(), receiptId);
    }

    function _getLpReceipt(
        LpReceiptStorage storage ls,
        uint256 receiptId
    ) private view returns (LpReceipt memory receipt) {
        receipt = ls.getReceipt(receiptId);
        if (receipt.id == 0) revert NotExistLpReceipt();
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function claimableLiquidity(
        int16 tradingFeeRate,
        uint256 oracleVersion
    ) external view returns (ClaimableLiquidity memory) {
        return
            MarketStorageLib.marketStorage().liquidityPool.claimableLiquidity(
                tradingFeeRate,
                oracleVersion
            );
    }

    /**
     * @inheritdoc IMarketLiquidity
     */
    function liquidityBinStatuses() external view returns (LiquidityBinStatus[] memory) {
        return MarketStorageLib.marketStorage().liquidityPool.liquidityBinStatuses(newLpContext());
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
    function _newLpReceipt(
        LpContext memory ctx,
        LpAction action,
        uint256 amount,
        address recipient,
        int16 tradingFeeRate
    ) private returns (LpReceipt memory) {
        return
            LpReceipt({
                id: LpReceiptStorageLib.lpReceiptStorage().nextId(),
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
        address /* operator */,
        address /* from */,
        uint256 /* id */,
        uint256 /* value */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @inheritdoc IERC1155Receiver
     */
    function onERC1155BatchReceived(
        address /* operator */,
        address /* from */,
        uint256[] calldata /* ids */,
        uint256[] calldata /* values */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.onERC1155Received.selector ^ this.onERC1155BatchReceived.selector; // IERC1155Receiver
    }
}
