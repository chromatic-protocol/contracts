// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {BaseSetup} from "../BaseSetup.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {OpenPositionInfo, ClaimPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import "forge-std/console.sol";

contract LiquidatorTest is BaseSetup, IChromaticTradeCallback, IChromaticLiquidityCallback {
    function setUp() public override {
        super.setUp();
    }

    function testLiquidate() public {
        uint256 liquidityAmount = 10 ether;

        // prepare bin
        LpReceipt memory receipt = market.addLiquidity(
            address(this),
            1,
            abi.encode(liquidityAmount)
        );
        oracleProvider.increaseVersion(1 ether);
        market.claimLiquidity(receipt.id, bytes(""));

        // open position when oracle price is 10 ether
        OpenPositionInfo memory position = market.openPosition(
            10 ether,
            1 ether,
            liquidityAmount,
            1 ether,
            bytes("")
        );
        oracleProvider.increaseVersion(10 ether);

        // set oracle price with 5 ether
        oracleProvider.increaseVersion(5 ether);

        // resolve liquidation
        (bool canExec, ) = liquidator.resolveLiquidation(address(market), position.id, "");
        assertEq(canExec, true);

        // liquidate
        liquidator.liquidate(address(market), position.id);
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

    function claimPositionCallback(
        Position memory /* position */,
        ClaimPositionInfo memory /* claimInfo */,
        bytes calldata /* data */
    ) external override {}

    // implement IChromaticLiquidityCallback

    function addLiquidityCallback(address, address vault, bytes calldata data) external override {
        uint256 amount = abi.decode(data, (uint256));
        ctst.transfer(vault, amount);
    }

    function addLiquidityBatchCallback(
        address,
        address vault,
        bytes calldata data
    ) external override {
        uint256 amount = abi.decode(data, (uint256));
        ctst.transfer(vault, amount);
    }

    function claimLiquidityCallback(
        uint256 receiptId,
        int16 feeRate,
        uint256 depositedAmount,
        uint256 mintedCLBTokenAmount,
        bytes calldata data
    ) external override {}

    function claimLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        int16[] calldata feeRates,
        uint256[] calldata depositedAmounts,
        uint256[] calldata mintedCLBTokenAmounts,
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

    function withdrawLiquidityCallback(
        uint256 receiptId,
        int16 feeRate,
        uint256 withdrawnAmount,
        uint256 burnedCLBTokenAmount,
        bytes calldata data
    ) external override {}

    function withdrawLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        int16[] calldata feeRates,
        uint256[] calldata withdrawnAmounts,
        uint256[] calldata burnedCLBTokenAmounts,
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
