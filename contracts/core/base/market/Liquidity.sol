// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IChromaticLiquidityCallback} from "@chromatic/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {LpReceipt, LpAction} from "@chromatic/core/libraries/LpReceipt.sol";
import {MarketBase} from "@chromatic/core/base/market/MarketBase.sol";

abstract contract Liquidity is MarketBase, IERC1155Receiver {
    using Math for uint256;

    uint256 constant MINIMUM_LIQUIDITY = 10 ** 3;

    uint256 internal _lpReceiptId;

    modifier onlyVault() {
        if (msg.sender != address(vault)) revert OnlyAccessableByVault();
        _;
    }

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

    function getBinLiquidities(
        int16[] calldata tradingFeeRates
    ) external view override returns (uint256[] memory amounts) {
        amounts = new uint256[](tradingFeeRates.length);
        for (uint i = 0; i < tradingFeeRates.length; i++) {
            amounts[i] = liquidityPool.getBinLiquidity(tradingFeeRates[i]);
        }
    }

    function getBinFreeLiquidities(
        int16[] calldata tradingFeeRates
    ) external view override returns (uint256[] memory amounts) {
        amounts = new uint256[](tradingFeeRates.length);
        for (uint i = 0; i < tradingFeeRates.length; i++) {
            amounts[i] = liquidityPool.getBinFreeLiquidity(tradingFeeRates[i]);
        }
    }

    function distributeEarningToBins(uint256 earning, uint256 marketBalance) external onlyVault {
        liquidityPool.distributeEarning(earning, marketBalance);
    }

    function getBinValues(
        int16[] calldata tradingFeeRates
    ) external view returns (uint256[] memory values) {
        values = liquidityPool.binValues(tradingFeeRates, newLpContext());
    }

    function calculateCLBTokenMinting(
        int16 tradingFeeRate,
        uint256 amount
    ) external view returns (uint256) {
        return liquidityPool.calculateCLBTokenMinting(newLpContext(), tradingFeeRate, amount);
    }

    function calculateCLBTokenValue(
        int16 tradingFeeRate,
        uint256 clbTokenAmount
    ) external view returns (uint256) {
        return liquidityPool.calculateCLBTokenValue(newLpContext(), tradingFeeRate, clbTokenAmount);
    }

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

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.onERC1155Received.selector ^ this.onERC1155BatchReceived.selector; // IERC1155Receiver
    }

    function getLpReceipt(uint256 receiptId) external view returns (LpReceipt memory receipt) {
        receipt = lpReceipts[receiptId];
        if (receipt.id == 0) revert NotExistLpReceipt();
    }

    function getClaimBurning(
        LpReceipt memory receipt
    ) external view returns (uint256 clbTokenAmount, uint256 burningAmount, uint256 tokenAmount) {
        return liquidityPool.getClaimBurning(receipt.tradingFeeRate, receipt.oracleVersion);
    }
}
