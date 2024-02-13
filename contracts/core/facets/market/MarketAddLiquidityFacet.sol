// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IMarketAddLiquidity} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketAddLiquidity.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {LpReceipt, LpAction} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {MarketStorage, MarketStorageLib, LpReceiptStorage, LpReceiptStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MarketLiquidityFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacetBase.sol";

/**
 * @title MarketAddLiquidityFacet
 * @dev Contract for adding and claiming liquidity in a market.
 */
contract MarketAddLiquidityFacet is ReentrancyGuard, MarketLiquidityFacetBase, IMarketAddLiquidity {
    /**
     * @inheritdoc IMarketAddLiquidity
     */
    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external override nonReentrant withTradingLock returns (LpReceipt memory receipt) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        IERC20Metadata settlementToken = IERC20Metadata(ctx.settlementToken);
        IChromaticVault vault = ctx.vault;

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
     * @inheritdoc IMarketAddLiquidity
     * @dev Throws an `InvalidTransferredTokenAmount` error if the transferred amount does not match the sum of amounts param.
     */
    function addLiquidityBatch(
        address recipient,
        int16[] calldata tradingFeeRates,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override nonReentrant withTradingLock returns (LpReceipt[] memory receipts) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        _requireFeeRatesUniqueness(tradingFeeRates);

        require(tradingFeeRates.length == amounts.length);

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
                ++i;
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
                ++i;
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
     * @inheritdoc IMarketAddLiquidity
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     *      Throws an `InvalidLpReceiptAction` error if the action of liquidity receipt is not `ADD_LIQUIDITY`.
     *      Throws a `NotClaimableLpReceipt` error if the liquidity receipt is not claimable in the current oracle version.
     */
    function claimLiquidity(
        uint256 receiptId,
        bytes calldata data
    ) external override nonReentrant withTradingLock {
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
     * @inheritdoc IMarketAddLiquidity
     * @dev Throws a `NotExistLpReceipt` error if the liquidity receipt does not exist.
     *      Throws an `InvalidLpReceiptAction` error if the action of liquidity receipt is not `ADD_LIQUIDITY`.
     *      Throws a `NotClaimableLpReceipt` error if the liquidity receipt is not claimable in the current oracle version.
     */
    function claimLiquidityBatch(
        uint256[] calldata receiptIds,
        bytes calldata data
    ) external override nonReentrant withTradingLock {
        LpReceiptStorage storage ls = LpReceiptStorageLib.lpReceiptStorage();
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        LpReceipt[] memory _receipts = new LpReceipt[](receiptIds.length);
        int16[] memory _feeRates = new int16[](receiptIds.length);
        uint256[] memory _tokenAmounts = new uint256[](receiptIds.length);
        uint256[] memory _clbTokenAmounts = new uint256[](receiptIds.length);

        for (uint256 i; i < receiptIds.length; ) {
            (_receipts[i], _clbTokenAmounts[i]) = _claimLiquidity(
                ctx,
                ls,
                ms.liquidityPool,
                receiptIds[i]
            );
            _feeRates[i] = _receipts[i].tradingFeeRate;
            _tokenAmounts[i] = _receipts[i].amount;

            unchecked {
                ++i;
            }
        }

        IChromaticLiquidityCallback(msg.sender).claimLiquidityBatchCallback(
            receiptIds,
            _feeRates,
            _tokenAmounts,
            _clbTokenAmounts,
            data
        );

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

        ls.deleteReceipt(receiptId);

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
     * @inheritdoc IMarketAddLiquidity
     */
    function distributeEarningToBins(uint256 earning, uint256 marketBalance) external onlyVault {
        MarketStorageLib.marketStorage().liquidityPool.distributeEarning(earning, marketBalance);
    }
}
