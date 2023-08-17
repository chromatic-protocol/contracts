// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {IVault} from "@chromatic-protocol/contracts/core/interfaces/vault/IVault.sol";
import {IMarketLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidity.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {LpReceipt, LpAction} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {MarketStorage, MarketStorageLib, LpReceiptStorage, LpReceiptStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MarketLiquidityFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacetBase.sol";

/**
 * @title MarketLiquidityFacet
 * @dev Contract for managing liquidity in a market.
 */
contract MarketLiquidityFacet is
    MarketLiquidityFacetBase,
    IMarketLiquidity,
    IERC1155Receiver,
    ReentrancyGuard
{
    using Math for uint256;

    /**
     * @dev Throws an error indicating that the amount of liquidity is too small.
     *      This error is thrown when attempting to remove liquidity with an amount of zero.
     */
    error TooSmallAmount();

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

    /**
     * @inheritdoc IMarketLiquidity
     */
    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant returns (LpReceipt memory receipt) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        IERC20Metadata settlementToken = IERC20Metadata(ctx.settlementToken);
        IVault vault = ctx.vault;

        uint256 balanceBefore = settlementToken.balanceOf(address(vault));
        IChromaticLiquidityCallback(msg.sender).addLiquidityCallback(
            address(settlementToken),
            address(vault),
            data
        );

        uint256 amount = settlementToken.balanceOf(address(vault)) - balanceBefore;

        vault.onAddLiquidity(ctx.settlementToken, amount);

        receipt = _addLiquidity(ctx, ms.liquidityPool, recipient, tradingFeeRate, amount);

        emit AddLiquidity(receipt);
    }

    /**
     * @inheritdoc IMarketLiquidity
     * @dev Throws an `InvalidTransferredTokenAmount` error if the transferred amount does not match the sum of amounts param.
     */
    function addLiquidityBatch(
        address recipient,
        int16[] calldata tradingFeeRates,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override nonReentrant returns (LpReceipt[] memory receipts) {
        require(tradingFeeRates.length == amounts.length);

        MarketStorage storage ms = MarketStorageLib.marketStorage();
        LiquidityPool storage liquidityPool = ms.liquidityPool;

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        uint256 totalAmount = _checkTransferredAmount(ctx, amounts, data);

        ctx.vault.onAddLiquidity(ctx.settlementToken, totalAmount);

        receipts = new LpReceipt[](tradingFeeRates.length);
        for (uint256 i; i < tradingFeeRates.length; ) {
            receipts[i] = _addLiquidity(
                ctx,
                liquidityPool,
                recipient,
                tradingFeeRates[i],
                amounts[i]
            );

            unchecked {
                i++;
            }
        }

        emit AddLiquidityBatch(receipts);
    }

    function _checkTransferredAmount(
        LpContext memory ctx,
        uint256[] calldata amounts,
        bytes calldata data
    ) private returns (uint256 totalAmount) {
        for (uint256 i; i < amounts.length; ) {
            totalAmount += amounts[i];

            unchecked {
                i++;
            }
        }

        IERC20Metadata settlementToken = IERC20Metadata(ctx.settlementToken);
        address vault = address(ctx.vault);

        uint256 balanceBefore = settlementToken.balanceOf(vault);
        IChromaticLiquidityCallback(msg.sender).addLiquidityBatchCallback(
            address(settlementToken),
            vault,
            data
        );

        uint256 transferredAmount = settlementToken.balanceOf(vault) - balanceBefore;
        if (transferredAmount != totalAmount) revert InvalidTransferredTokenAmount();
    }

    function _addLiquidity(
        LpContext memory ctx,
        LiquidityPool storage liquidityPool,
        address recipient,
        int16 tradingFeeRate,
        uint256 amount
    ) private returns (LpReceipt memory receipt) {
        liquidityPool.acceptAddLiquidity(ctx, tradingFeeRate, amount);

        receipt = _newLpReceipt(ctx, LpAction.ADD_LIQUIDITY, amount, recipient, tradingFeeRate);
        LpReceiptStorageLib.lpReceiptStorage().setReceipt(receipt);
    }

    /**
     * @inheritdoc IMarketLiquidity
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     *      Throws an `InvalidLpReceiptAction` error if the action of liquidity receipt is not `ADD_LIQUIDITY`.
     *      Throws a `NotClaimableLpReceipt` error if the liquidity receipt is not claimable in the current oracle version.
     */
    function claimLiquidity(uint256 receiptId, bytes calldata data) external override nonReentrant {
        LpReceiptStorage storage ls = LpReceiptStorageLib.lpReceiptStorage();
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        (LpReceipt memory receipt, uint256 clbTokenAmount) = _claimLiquidity(
            ctx,
            ls,
            ms.liquidityPool,
            receiptId
        );

        IChromaticLiquidityCallback(msg.sender).claimLiquidityCallback(
            receiptId,
            receipt.tradingFeeRate,
            receipt.amount,
            clbTokenAmount,
            data
        );
        ls.deleteReceipt(receiptId);

        emit ClaimLiquidity(receipt, clbTokenAmount);
    }

    /**
     * @inheritdoc IMarketLiquidity
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     *      Throws an `InvalidLpReceiptAction` error if the action of liquidity receipt is not `ADD_LIQUIDITY`.
     *      Throws a `NotClaimableLpReceipt` error if the liquidity receipt is not claimable in the current oracle version.
     */
    function claimLiquidityBatch(
        uint256[] calldata receiptIds,
        bytes calldata data
    ) external override nonReentrant {
        LpReceiptStorage storage ls = LpReceiptStorageLib.lpReceiptStorage();
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        LpReceipt[] memory _receipts = new LpReceipt[](receiptIds.length);
        int16[] memory _feeRates = new int16[](receiptIds.length);
        uint256[] memory _tokenAmounts = new uint256[](receiptIds.length);
        uint256[] memory _clbTokenAmounts = new uint256[](receiptIds.length);

        for (uint256 i; i < receiptIds.length; i++) {
            (_receipts[i], _clbTokenAmounts[i]) = _claimLiquidity(
                ctx,
                ls,
                ms.liquidityPool,
                receiptIds[i]
            );
            _feeRates[i] = _receipts[i].tradingFeeRate;
            _tokenAmounts[i] = _receipts[i].amount;
        }

        IChromaticLiquidityCallback(msg.sender).claimLiquidityBatchCallback(
            receiptIds,
            _feeRates,
            _tokenAmounts,
            _clbTokenAmounts,
            data
        );
        ls.deleteReceipts(receiptIds);

        emit ClaimLiquidityBatch(_receipts, _clbTokenAmounts);
    }

    function _claimLiquidity(
        LpContext memory ctx,
        LpReceiptStorage storage ls,
        LiquidityPool storage liquidityPool,
        uint256 receiptId
    ) private returns (LpReceipt memory receipt, uint256 clbTokenAmount) {
        receipt = _getLpReceipt(ls, receiptId);
        if (receipt.action != LpAction.ADD_LIQUIDITY) revert InvalidLpReceiptAction();
        if (!ctx.isPastVersion(receipt.oracleVersion)) revert NotClaimableLpReceipt();

        clbTokenAmount = liquidityPool.acceptClaimLiquidity(
            ctx,
            receipt.tradingFeeRate,
            receipt.amount,
            receipt.oracleVersion
        );
        if (clbTokenAmount > 0) {
            //slither-disable-next-line calls-loop
            ctx.clbToken.safeTransferFrom(
                address(this),
                receipt.recipient,
                receipt.clbTokenId(),
                clbTokenAmount,
                bytes("")
            );
        }
    }

    /**
     * @inheritdoc IMarketLiquidity
     * @dev This function is called by the liquidity provider to remove their liquidity from the market.
     *      The liquidity provider must have previously added liquidity to the market.
     *      Throws a `TooSmallAmount` error if the CLB tokne amount of liquidity to be removed is zero.
     */
    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant returns (LpReceipt memory receipt) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();

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
     * @inheritdoc IMarketLiquidity
     * @dev Throws an `InvalidTransferredTokenAmount` error if the transferred CLB token amount does not match the expected amount (clbTokenAmounts param).
     */
    function removeLiquidityBatch(
        address recipient,
        int16[] calldata tradingFeeRates,
        uint256[] calldata clbTokenAmounts,
        bytes calldata data
    ) external override nonReentrant returns (LpReceipt[] memory receipts) {
        require(tradingFeeRates.length == clbTokenAmounts.length);

        MarketStorage storage ms = MarketStorageLib.marketStorage();
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
                i++;
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
                i++;
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
                i++;
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
     * @inheritdoc IMarketLiquidity
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     *      Throws an `InvalidLpReceiptAction` error if the action of liquidity receipt is not `REMOVE_LIQUIDITY`.
     *      Throws a `NotWithdrawableLpReceipt` error if the liquidity receipt is not withdrawable in the current oracle version.
     */
    function withdrawLiquidity(
        uint256 receiptId,
        bytes calldata data
    ) external override nonReentrant {
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
     * @inheritdoc IMarketLiquidity
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     *      Throws an `InvalidLpReceiptAction` error if the action of liquidity receipt is not `REMOVE_LIQUIDITY`.
     *      Throws a `NotWithdrawableLpReceipt` error if the liquidity receipt is not withdrawable in the current oracle version.
     */
    function withdrawLiquidityBatch(
        uint256[] calldata receiptIds,
        bytes calldata data
    ) external override nonReentrant {
        LpReceiptStorage storage ls = LpReceiptStorageLib.lpReceiptStorage();
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        LpReceipt[] memory _receipts = new LpReceipt[](receiptIds.length);
        int16[] memory _feeRates = new int16[](receiptIds.length);
        uint256[] memory _amounts = new uint256[](receiptIds.length);
        uint256[] memory _burnedCLBTokenAmounts = new uint256[](receiptIds.length);

        for (uint256 i; i < receiptIds.length; i++) {
            (_receipts[i], _amounts[i], _burnedCLBTokenAmounts[i]) = _withdrawLiquidity(
                ctx,
                ls,
                ms.liquidityPool,
                receiptIds[i]
            );
            _feeRates[i] = _receipts[i].tradingFeeRate;
        }

        IChromaticLiquidityCallback(msg.sender).withdrawLiquidityBatchCallback(
            receiptIds,
            _feeRates,
            _amounts,
            _burnedCLBTokenAmounts,
            data
        );
        ls.deleteReceipts(receiptIds);

        emit WithdrawLiquidityBatch(_receipts, _amounts, _burnedCLBTokenAmounts);
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
     * @inheritdoc IMarketLiquidity
     */
    function distributeEarningToBins(uint256 earning, uint256 marketBalance) external onlyVault {
        MarketStorageLib.marketStorage().liquidityPool.distributeEarning(earning, marketBalance);
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
