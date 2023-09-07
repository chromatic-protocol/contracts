// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {BaseSetup} from "../BaseSetup.sol";

import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPBase} from "@chromatic-protocol/contracts/lp/base/ChromaticLPBase.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";
import {MarketLiquidityFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacet.sol";

import "forge-std/console.sol";

contract ChromaticLPTest is BaseSetup {
    IChromaticLP lp;

    event AddLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 amount
    );

    event AddLiquiditySettled(uint256 indexed receiptId, uint256 lpTokenAmount);

    event RemoveLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 lpTokenAmount
    );

    event RemoveLiquiditySettled(uint256 indexed receiptId);

    event RebalanceLiquidity(uint256 indexed receiptId);
    event RebalanceSettled(uint256 indexed receiptId);

    function setUp() public override {
        super.setUp();
        int8[8] memory _feeRates = [-4, -3, -2, -1, 1, 2, 3, 4];
        uint16[8] memory _distributions = [2000, 1500, 1000, 500, 500, 1000, 1500, 2000];

        int16[] memory feeRates = new int16[](_feeRates.length);
        uint16[] memory distributionRates = new uint16[](_feeRates.length);
        for (uint256 i; i < _feeRates.length; i++) {
            feeRates[i] = _feeRates[i];
            distributionRates[i] = _distributions[i];
        }

        lp = new ChromaticLPBase(
            market,
            5000,
            500,
            feeRates,
            distributionRates,
            1 hours,
            1 minutes,
            address(automate),
            address(opf)
        );

        // usdc.faucet(1000 ether);
    }

    function consoleReceipt(ChromaticLPReceipt memory receipt) internal view {
        console.log("{");
        console.log("  id:", receipt.id);
        console.log("  oracleVersion:", receipt.oracleVersion);
        console.log("  amount:", receipt.amount / 10 ** 18, "ether");
        console.log("  recipient:", receipt.recipient);
        console.log("  action:", uint256(receipt.action));
        console.log("}");
    }

    function testAddLiquidity() public {
        assertEq(lp.totalSupply(), 0);

        // by super.setUp()
        assertEq(usdc.balanceOf(address(this)), 1000000 ether);

        // approve first
        usdc.approve(address(lp), 1000000 ether);

        vm.expectEmit(true, true, false, true, address(lp));
        uint256 amount = 1000 ether;
        emit AddLiquidity(1, address(this), oracleProvider.currentVersion().version, amount);

        ChromaticLPReceipt memory receipt = lp.addLiquidity(amount, address(this));
        console.log("ChromaticLPReceipt:", receipt.id);

        uint256[] memory receiptIds = lp.getReceiptIds(address(this));

        assertEq(receiptIds.length, 1);
        assertEq(receipt.id, receiptIds[0]);

        assertEq(false, lp.settle(receipt.id));

        uint256 tokenBalanceBefore = lp.balanceOf(address(this));

        oracleProvider.increaseVersion(3 ether);

        vm.expectEmit(true, false, false, true, address(lp));
        emit AddLiquiditySettled(receipt.id, receipt.amount);
        assertEq(true, lp.settle(receipt.id));

        uint256 tokenBalanceAfter = lp.balanceOf(address(this));
        assertEq(tokenBalanceBefore, 0);
        assertEq(tokenBalanceAfter - tokenBalanceBefore, receipt.amount);

        receiptIds = lp.getReceiptIds(address(this));
        assertEq(0, receiptIds.length);
        receipt = lp.getReceipt(receipt.id);
        assertEq(0, receipt.id);
    }

    function testRemoveLiquidity() public {
        testAddLiquidity();
        uint256 lptoken = lp.balanceOf(address(this)); // 1000 ether

        lp.approve(address(lp), lptoken);

        vm.expectEmit(true, true, false, true, address(lp));
        emit RemoveLiquidity(2, address(this), oracleProvider.currentVersion().version, lptoken);

        ChromaticLPReceipt memory receipt = lp.removeLiquidity(lptoken, address(this));

        uint256[] memory receiptIds = lp.getReceiptIds(address(this));

        assertEq(receiptIds.length, 1);
        assertEq(receipt.id, receiptIds[0]);

        assertEq(false, lp.settle(receipt.id));

        uint256 tokenBalanceBefore = usdc.balanceOf(address(this));
        oracleProvider.increaseVersion(3 ether);

        vm.expectEmit(true, false, false, true, address(lp));
        emit RemoveLiquiditySettled(receipt.id);
        assertEq(true, lp.settle(receipt.id));
        uint256 tokenBalanceAfter = usdc.balanceOf(address(this));
        assertEq(tokenBalanceAfter - tokenBalanceBefore, receipt.amount);
    }
}
