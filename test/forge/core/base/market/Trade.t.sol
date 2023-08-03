// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {BaseSetup} from "../../../BaseSetup.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";

contract TradeTest is BaseSetup, IChromaticLiquidityCallback, IChromaticTradeCallback {
    function setUp() public override {
        super.setUp();
    }

    function testOpenPositionAfterRemoveLiquidity() public {
        uint256 liquidityAmount = 10 ether;

        // set oracle version to 1
        oracleProvider.increaseVersion(1 ether);

        // add liquidity $10 to 0.01% and 0.02% long bin at oracle version 1
        LpReceipt memory receipt1 = market.addLiquidity(
            address(this),
            1,
            abi.encode(liquidityAmount)
        );
        LpReceipt memory receipt2 = market.addLiquidity(
            address(this),
            2,
            abi.encode(liquidityAmount)
        );

        // set oracle version to 2
        oracleProvider.increaseVersion(1 ether);

        // claim liquidity at oracle version 2
        market.claimLiquidity(receipt1.id, bytes(""));
        market.claimLiquidity(receipt2.id, bytes(""));
        assertEq(liquidityAmount, clbToken.balanceOf(address(this), receipt1.clbTokenId()));

        // open position at oracle version 2
        Position memory position1 = market.openPosition(
            10 ether,
            1 ether,
            liquidityAmount,
            1 ether,
            bytes("")
        );

        // set oracle version to 3
        oracleProvider.increaseVersion(1 ether);

        // close position at oracle version 3
        market.closePosition(position1.id);
        assertEq(liquidityAmount + position1.tradingFee(), market.getBinLiquidity(1));
        assertEq(position1.tradingFee(), market.getBinFreeLiquidity(1));

        // set oracle version to 4
        oracleProvider.increaseVersion(1.1 ether);

        // remove liquidity and claim position at oracle version 4
        LpReceipt memory receipt3 = market.removeLiquidity(
            address(this),
            1,
            abi.encode(liquidityAmount)
        );
        assertEq(liquidityAmount + position1.tradingFee(), market.getBinLiquidity(1));
        assertEq(position1.tradingFee(), market.getBinFreeLiquidity(1));

        uint256 balanceBefore = usdc.balanceOf(address(this));

        market.claimPosition(position1.id, address(this), bytes(""));

        assertEq(2 ether, usdc.balanceOf(address(this)) - balanceBefore);
        assertEq(liquidityAmount + position1.tradingFee() - 1 ether, market.getBinLiquidity(1));
        assertEq(liquidityAmount + position1.tradingFee() - 1 ether, market.getBinFreeLiquidity(1));

        // set oracle version to 5
        oracleProvider.increaseVersion(1.1 ether);

        // open position at oracle version 5
        Position memory position2 = market.openPosition(
            10 ether,
            1 ether,
            liquidityAmount,
            1 ether,
            bytes("")
        );

        assertEq(0, market.getBinLiquidity(1));
        assertEq(liquidityAmount + position2.tradingFee(), market.getBinLiquidity(2));
        assertEq(position2.tradingFee(), market.getBinFreeLiquidity(2));

        // withdraw liquidity at oracle version 5
        balanceBefore = usdc.balanceOf(address(this));

        market.withdrawLiquidity(receipt3.id, bytes(""));

        assertEq(
            liquidityAmount + position1.tradingFee() - 1 ether,
            usdc.balanceOf(address(this)) - balanceBefore
        );
        assertEq(0, clbToken.balanceOf(address(this), 1));
    }

    // implement IChromaticTradeCallback

    function openPositionCallback(
        address settlementToken,
        address vault,
        uint256 marginRequired,
        bytes calldata /* data */
    ) external override {
        SafeERC20.safeTransfer(IERC20(settlementToken), vault, marginRequired);
    }

    /**
     * @inheritdoc IChromaticTradeCallback
     */
    function claimPositionCallback(
        Position memory /* position */,
        uint256 /* entryPrice */,
        uint256 /* exitPrice */,
        int256 /* realizedPnl */,
        uint256 /* interest */,
        bytes calldata /* data */
    ) external override {}

    // implement IChromaticLiquidityCallback

    function addLiquidityCallback(address, address vault, bytes calldata data) external override {
        uint256 amount = abi.decode(data, (uint256));
        usdc.transfer(vault, amount);
    }

    function addLiquidityBatchCallback(
        address,
        address vault,
        bytes calldata data
    ) external override {
        uint256 amount = abi.decode(data, (uint256));
        usdc.transfer(vault, amount);
    }

    function claimLiquidityCallback(uint256 receiptId, bytes calldata data) external override {}

    function claimLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        bytes calldata data
    ) external override {}

    function removeLiquidityCallback(
        address clbToken,
        uint256 clbTokenId,
        bytes calldata data
    ) external override {
        uint256 amount = abi.decode(data, (uint256));
        IERC1155(clbToken).safeTransferFrom(
            address(this),
            msg.sender,
            clbTokenId,
            amount,
            bytes("")
        );
    }

    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata clbTokenIds,
        bytes calldata data
    ) external override {
        uint256[] memory amounts = abi.decode(data, (uint256[]));
        IERC1155(clbToken).safeBatchTransferFrom(
            address(this),
            msg.sender,
            clbTokenIds,
            amounts,
            bytes("")
        );
    }

    function withdrawLiquidityCallback(uint256 receiptId, bytes calldata data) external override {}

    function withdrawLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        bytes calldata data
    ) external override {}

    // implement IERC1155Receiver

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
