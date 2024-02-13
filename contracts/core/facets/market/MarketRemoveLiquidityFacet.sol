// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {LiquidityMode} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {IMarketRemoveLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketRemoveLiquidity.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {LpReceipt, LpAction} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {MarketStorage, MarketStorageLib, LpReceiptStorage, LpReceiptStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MarketLiquidityFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacetBase.sol";

/**
 * @title MarketRemoveLiquidityFacet
 * @dev Contract for managing liquidity in a market.
 */
contract MarketRemoveLiquidityFacet is
    ReentrancyGuard,
    MarketLiquidityFacetBase,
    IMarketRemoveLiquidity,
    IERC1155Receiver
{
    /**
     * @inheritdoc IMarketRemoveLiquidity
     * @dev This function is called by the liquidity provider to remove their liquidity from the market.
     *      The liquidity provider must have previously added liquidity to the market.
     *      Throws a `TooSmallAmount` error if the CLB token amount of liquidity to be removed is zero.
     */
    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant withTradingLock returns (LpReceipt memory receipt) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        _requireRemoveLiquidityEnabled(ms);

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        uint256 clbTokenId = CLBTokenLib.encodeId(tradingFeeRate);
        uint256 balanceBefore = ctx.clbToken.balanceOf(address(this), clbTokenId);
        IChromaticLiquidityCallback(msg.sender).removeLiquidityCallback(
            address(ctx.clbToken),
            clbTokenId,
            data
        );

        uint256 clbTokenAmount = ctx.clbToken.balanceOf(address(this), clbTokenId) - balanceBefore;
        if (clbTokenAmount == 0) revert TooSmallAmount();

        receipt = _removeLiquidity(
            ctx,
            ms.liquidityPool,
            recipient,
            tradingFeeRate,
            clbTokenAmount
        );

        emit RemoveLiquidity(receipt);
    }

    /**
     * @inheritdoc IMarketRemoveLiquidity
     * @dev Throws an `InvalidTransferredTokenAmount` error if the transferred CLB token amount does not match the expected amount (clbTokenAmounts param).
     */
    function removeLiquidityBatch(
        address recipient,
        int16[] calldata tradingFeeRates,
        uint256[] calldata clbTokenAmounts,
        bytes calldata data
    ) external override nonReentrant withTradingLock returns (LpReceipt[] memory receipts) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        _requireRemoveLiquidityEnabled(ms);
        _requireFeeRatesUniqueness(tradingFeeRates);

        require(tradingFeeRates.length == clbTokenAmounts.length);

        LiquidityPool storage liquidityPool = ms.liquidityPool;

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        _checkTransferredCLBTokenAmount(ctx, tradingFeeRates, clbTokenAmounts, data);

        receipts = new LpReceipt[](tradingFeeRates.length);
        for (uint256 i; i < tradingFeeRates.length; ) {
            receipts[i] = _removeLiquidity(
                ctx,
                liquidityPool,
                recipient,
                tradingFeeRates[i],
                clbTokenAmounts[i]
            );

            unchecked {
                ++i;
            }
        }

        emit RemoveLiquidityBatch(receipts);
    }

    function _checkTransferredCLBTokenAmount(
        LpContext memory ctx,
        int16[] calldata tradingFeeRates,
        uint256[] calldata clbTokenAmounts,
        bytes calldata data
    ) private {
        address[] memory _accounts = new address[](tradingFeeRates.length);
        uint256[] memory _clbTokenIds = new uint256[](tradingFeeRates.length);
        for (uint256 i; i < tradingFeeRates.length; ) {
            _accounts[i] = address(this);
            _clbTokenIds[i] = CLBTokenLib.encodeId(tradingFeeRates[i]);

            unchecked {
                ++i;
            }
        }

        uint256[] memory balancesBefore = ctx.clbToken.balanceOfBatch(_accounts, _clbTokenIds);
        IChromaticLiquidityCallback(msg.sender).removeLiquidityBatchCallback(
            address(ctx.clbToken),
            _clbTokenIds,
            data
        );

        uint256[] memory balancesAfter = ctx.clbToken.balanceOfBatch(_accounts, _clbTokenIds);
        for (uint256 i; i < tradingFeeRates.length; ) {
            if (clbTokenAmounts[i] != balancesAfter[i] - balancesBefore[i])
                revert InvalidTransferredTokenAmount();

            unchecked {
                ++i;
            }
        }
    }

    function _removeLiquidity(
        LpContext memory ctx,
        LiquidityPool storage liquidityPool,
        address recipient,
        int16 tradingFeeRate,
        uint256 clbTokenAmount
    ) private returns (LpReceipt memory receipt) {
        liquidityPool.acceptRemoveLiquidity(ctx, tradingFeeRate, clbTokenAmount);

        receipt = _newLpReceipt(
            ctx,
            LpAction.REMOVE_LIQUIDITY,
            clbTokenAmount,
            recipient,
            tradingFeeRate
        );
        LpReceiptStorageLib.lpReceiptStorage().setReceipt(receipt);
    }

    /**
     * @inheritdoc IMarketRemoveLiquidity
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     *      Throws an `InvalidLpReceiptAction` error if the action of liquidity receipt is not `REMOVE_LIQUIDITY`.
     *      Throws a `NotWithdrawableLpReceipt` error if the liquidity receipt is not withdrawable in the current oracle version.
     */
    function withdrawLiquidity(
        uint256 receiptId,
        bytes calldata data
    ) external override nonReentrant withTradingLock {
        LpReceiptStorage storage ls = LpReceiptStorageLib.lpReceiptStorage();
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        (
            LpReceipt memory receipt,
            uint256 amount,
            uint256 burnedCLBTokenAmount
        ) = _withdrawLiquidity(ctx, ls, ms.liquidityPool, receiptId);

        IChromaticLiquidityCallback(msg.sender).withdrawLiquidityCallback(
            receiptId,
            receipt.tradingFeeRate,
            amount,
            burnedCLBTokenAmount,
            data
        );
        ls.deleteReceipt(receiptId);

        emit WithdrawLiquidity(receipt, amount, burnedCLBTokenAmount);
    }

    /**
     * @inheritdoc IMarketRemoveLiquidity
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     *      Throws an `InvalidLpReceiptAction` error if the action of liquidity receipt is not `REMOVE_LIQUIDITY`.
     *      Throws a `NotWithdrawableLpReceipt` error if the liquidity receipt is not withdrawable in the current oracle version.
     */
    function withdrawLiquidityBatch(
        uint256[] calldata receiptIds,
        bytes calldata data
    ) external override nonReentrant withTradingLock {
        LpReceiptStorage storage ls = LpReceiptStorageLib.lpReceiptStorage();
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        (
            LpReceipt[] memory _receipts,
            int16[] memory _feeRates,
            uint256[] memory _amounts,
            uint256[] memory _burnedCLBTokenAmounts // uint256[] memory _burnedCLBTokenAmounts
        ) = _withdrawLiquidityBatch(ctx, ls, ms.liquidityPool, receiptIds);

        IChromaticLiquidityCallback(msg.sender).withdrawLiquidityBatchCallback(
            receiptIds,
            _feeRates,
            _amounts,
            _burnedCLBTokenAmounts,
            data
        );

        emit WithdrawLiquidityBatch(_receipts, _amounts, _burnedCLBTokenAmounts);
    }

    function _withdrawLiquidityBatch(
        LpContext memory ctx,
        LpReceiptStorage storage ls,
        LiquidityPool storage liquidityPool,
        uint256[] calldata receiptIds
    )
        private
        returns (
            LpReceipt[] memory _receipts,
            int16[] memory _feeRates,
            uint256[] memory _amounts,
            uint256[] memory _burnedCLBTokenAmounts
        )
    {
        _receipts = new LpReceipt[](receiptIds.length);
        _feeRates = new int16[](receiptIds.length);
        _amounts = new uint256[](receiptIds.length);
        _burnedCLBTokenAmounts = new uint256[](receiptIds.length);

        for (uint256 i; i < receiptIds.length; ) {
            (_receipts[i], _amounts[i], _burnedCLBTokenAmounts[i]) = _withdrawLiquidity(
                ctx,
                ls,
                liquidityPool,
                receiptIds[i]
            );
            _feeRates[i] = _receipts[i].tradingFeeRate;
            unchecked {
                ++i;
            }
        }
    }

    function _withdrawLiquidity(
        LpContext memory ctx,
        LpReceiptStorage storage ls,
        LiquidityPool storage liquidityPool,
        uint256 receiptId
    ) private returns (LpReceipt memory receipt, uint256 amount, uint256 burnedCLBTokenAmount) {
        receipt = _getLpReceipt(ls, receiptId);
        if (receipt.action != LpAction.REMOVE_LIQUIDITY) revert InvalidLpReceiptAction();
        if (!ctx.isPastVersion(receipt.oracleVersion)) revert NotWithdrawableLpReceipt();

        ls.deleteReceipt(receiptId);

        address recipient = receipt.recipient;
        uint256 clbTokenAmount = receipt.amount;

        (amount, burnedCLBTokenAmount) = liquidityPool.acceptWithdrawLiquidity(
            ctx,
            receipt.tradingFeeRate,
            clbTokenAmount,
            receipt.oracleVersion
        );
        if (clbTokenAmount > burnedCLBTokenAmount) {
            //slither-disable-next-line calls-loop
            ctx.clbToken.safeTransferFrom(
                address(this),
                recipient,
                receipt.clbTokenId(),
                clbTokenAmount - burnedCLBTokenAmount,
                bytes("")
            );
        }
        //slither-disable-next-line calls-loop
        ctx.vault.onWithdrawLiquidity(ctx.settlementToken, recipient, amount);
    }

    /**
     * @dev Throws if remove liquidity is disabled.
     */
    function _requireRemoveLiquidityEnabled(MarketStorage storage ms) internal view virtual {
        LiquidityMode mode = ms.liquidityMode;
        if (mode == LiquidityMode.RemoveDisabled || mode == LiquidityMode.Suspended) {
            revert RemoveLiquidityDisabled();
        }
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
