// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {BaseSetup} from "../BaseSetup.sol";

import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";
import {ChromaticLP} from "@chromatic-protocol/contracts/lp/ChromaticLP.sol";
import {ChromaticLPLogic} from "@chromatic-protocol/contracts/lp/ChromaticLPLogic.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";
import {MarketLiquidityFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacet.sol";
import {IChromaticRouter} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticRouter.sol";
import {OpenPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTrade.sol";
import {IChromaticLPLens, ValueInfo} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLPLens.sol";
import {ChromaticLPStorage} from "@chromatic-protocol/contracts/lp/ChromaticLPStorage.sol";
import {IChromaticAccount} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticAccount.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {CLAIM_USER} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTrade.sol";

import "forge-std/console.sol";

contract Taker {
    IChromaticRouter router;

    constructor(IChromaticRouter _router) {
        router = _router;
    }

    function createAccount() public {
        router.createAccount();
    }

    function getAccount() external view returns (address) {
        return router.getAccount();
    }

    function openPosition(
        address market,
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external returns (OpenPositionInfo memory) {
        return router.openPosition(market, qty, takerMargin, makerMargin, maxAllowableTradingFee);
    }

    function claimPosition(address market, uint256 positionId) external {
        router.claimPosition(market, positionId);
    }

    function closePosition(address market, uint256 positionId) external {
        router.closePosition(market, positionId);
    }
}

contract ChromaticLPTest is BaseSetup {
    using Math for uint256;

    ChromaticLP lp;
    IChromaticLPLens lens;
    ChromaticLPLogic lpLogic;

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

    event ClaimPosition(
        address indexed marketAddress,
        uint256 indexed positionId,
        uint256 entryPrice,
        uint256 exitPrice,
        int256 realizedPnl,
        uint256 interest,
        bytes4 cause
    );

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

        lpLogic = new ChromaticLPLogic(
            ChromaticLPStorage.AutomateParam({
                automate: address(automate),
                opsProxyFactory: address(opf)
            })
        );

        lp = new ChromaticLP(
            lpLogic,
            ChromaticLPStorage.Config({
                market: market,
                utilizationTargetBPS: 5000,
                rebalanceBPS: 500,
                rebalnceCheckingInterval: 1 hours,
                settleCheckingInterval: 1 minutes
            }),
            feeRates,
            distributionRates,
            ChromaticLPStorage.AutomateParam({
                automate: address(automate),
                opsProxyFactory: address(opf)
            })
        );
        console.log("LP address: ", address(lp));
        console.log("LP logic address: ", address(lpLogic));
    }

    function logReceipt(ChromaticLPReceipt memory receipt) internal view {
        console.log("{");
        console.log("Receipt");
        console.log("  id:", receipt.id);
        console.log("  oracleVersion:", receipt.oracleVersion);
        console.log("  amount:", receipt.amount / 10 ** 18, "ether");
        console.log("  recipient:", receipt.recipient);
        console.log("  action:", uint256(receipt.action));
        console.log("}");
    }

    function logLpValue() internal view {
        console.log("{");
        console.log("LP values");
        ValueInfo memory value = lp.valueInfo();
        console.log("  total: ", value.total / 10 ** 18);
        console.log("  holding: ", value.holding / 10 ** 18);
        console.log("  pending: ", value.pending / 10 ** 18);
        console.log("  holdingClb: ", value.holdingClb / 10 ** 18);
        console.log("  pendingClb: ", value.pendingClb / 10 ** 18);
        console.log("}");
    }

    function testAddLiquidity() public {
        assertEq(lp.totalSupply(), 0);
        logLpValue();

        // by super.setUp()
        assertEq(usdc.balanceOf(address(this)), 1000000 ether);
        oracleProvider.increaseVersion(3 ether);
        // approve first
        usdc.approve(address(lp), 1000000 ether);

        vm.expectEmit(true, true, false, true, address(lp));
        uint256 amount = 1000 ether;
        emit AddLiquidity(1, address(this), oracleProvider.currentVersion().version, amount);

        ChromaticLPReceipt memory receipt = lp.addLiquidity(amount, address(this));
        console.log("ChromaticLPReceipt:", receipt.id);

        uint256[] memory receiptIds = lp.getReceiptIdsOf(address(this));

        assertEq(receiptIds.length, 1);
        assertEq(receipt.id, receiptIds[0]);
        assertEq(receipt.amount, amount);

        // logReceipt(receipt);
        logLpValue();

        assertEq(false, lp.settle(receipt.id));

        uint256 tokenBalanceBefore = lp.balanceOf(address(this));
        oracleProvider.increaseVersion(3 ether);

        vm.expectEmit(true, false, false, true, address(lp));
        emit AddLiquiditySettled(receipt.id, receipt.amount);
        assertEq(true, lp.settle(receipt.id));

        uint256 tokenBalanceAfter = lp.balanceOf(address(this));
        assertEq(tokenBalanceBefore, 0);
        assertEq(tokenBalanceAfter - tokenBalanceBefore, receipt.amount);

        receiptIds = lp.getReceiptIdsOf(address(this));
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

        uint256[] memory receiptIds = lp.getReceiptIdsOf(address(this));

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

    function consoleOpenPositionInfo(OpenPositionInfo memory info) internal view {
        console.log("OpenPositionInfo:");
        console.log("{");
        console.log("  id:", info.id);
        console.log("  openTimestamp:", info.openTimestamp);
        console.log("  openVersion:", info.openVersion);
        if (info.qty >= 0) {
            console.log("  qty:", uint256(info.qty) / (10 ** 18), "ether");
        } else {
            console.log("  qty: -", uint256(info.qty) / (10 ** 18), "ether");
        }
        console.log("  takerMargin:", info.takerMargin / 10 ** 18, "ether");
        console.log("  makerMargin:", info.makerMargin / 10 ** 18, "ether");
        console.log("  tradingFee:", info.tradingFee / 10 ** 18, "ether");
        console.log("}");
    }

    function logLP() public view {
        console.log("ChromaticLP:");
        console.log("{");
        console.log("{");
        console.log("LP values");
        ValueInfo memory value = lp.valueInfo();
        console.log("  total: ", value.total / 10 ** 18);
        console.log("  holding: ", value.holding / 10 ** 18);
        console.log("  pending: ", value.pending / 10 ** 18);
        console.log("  holdingClb: ", value.holdingClb / 10 ** 18);
        console.log("  pendingClb: ", value.pendingClb / 10 ** 18);
        console.log("  utilizationBPS: ", lp.utilization());
        console.log("}");
        // logCLB();
    }

    function logCLB() public view {
        uint256[] memory clbBalances = lp.clbTokenBalances();
        int16[] memory feeRates = lp.feeRates();
        console.log("clbBalances:");
        console.log("{");
        for (uint256 i; i < feeRates.length; i++) {
            if (clbBalances[i] != 0) {
                console.log("  ");
                console.logInt(int256(feeRates[i]));
                console.log(": ");
                console.log(clbBalances[i] / 10 ** 18);
                console.log("  %s: %e", vm.toString(int256(feeRates[i])), clbBalances[i]);
            }
        }
        console.log("}");
    }

    function testLossRemoveLiquidity() public {
        // logLP();
        testAddLiquidity();
        // logCLB();

        Taker taker = new Taker(router);
        taker.createAccount();
        usdc.transfer(taker.getAccount(), 100 ether);
        uint256 balanceBefore = usdc.balanceOf(taker.getAccount());

        OpenPositionInfo memory openinfo = taker.openPosition(
            address(market),
            100 ether,
            10 ether,
            100 ether,
            1 ether
        );
        consoleOpenPositionInfo(openinfo);

        (bool canExec, ) = lp.resolveRebalance();
        assertEq(canExec, false);

        int256 entryPrice = 1 ether;
        int256 exitPrice = 2 ether;

        oracleProvider.increaseVersion(entryPrice);
        market.settleAll();

        taker.closePosition(address(market), openinfo.id);

        oracleProvider.increaseVersion(exitPrice);
        (canExec, ) = lp.resolveRebalance();
        assertEq(canExec, false);

        market.settleAll();

        vm.expectEmit(true, true, false, true, taker.getAccount());
        emit ClaimPosition(
            address(market),
            openinfo.id,
            uint256(entryPrice),
            uint256(exitPrice),
            (openinfo.qty * (exitPrice - entryPrice)) / 10 ** 18,
            0,
            CLAIM_USER
        );
        taker.claimPosition(address(market), openinfo.id);

        uint256 balanceAfter = usdc.balanceOf(taker.getAccount());
        console.log("balance before and after", balanceBefore / 10 ** 18, balanceAfter / 10 ** 18);
        (canExec, ) = lp.resolveRebalance();
        assertEq(canExec, true);

        lp.rebalance();
    }

    function testTradeRemoveLiquidity() public {
        // logLP();
        testAddLiquidity();
        // logCLB();

        Taker taker = new Taker(router);
        taker.createAccount();
        usdc.transfer(taker.getAccount(), 100 ether);
        // uint256 balanceBefore = usdc.balanceOf(taker.getAccount());

        OpenPositionInfo memory openinfo = taker.openPosition(
            address(market),
            100 ether,
            10 ether,
            100 ether,
            1 ether
        );
        consoleOpenPositionInfo(openinfo);

        (bool canExec, ) = lp.resolveRebalance();
        assertEq(canExec, false);

        int256 entryPrice = 1 ether;
        int256 exitPrice = 2 ether;

        oracleProvider.increaseVersion(entryPrice);
        market.settleAll();

        uint256 lptoken = lp.balanceOf(address(this));
        console.log("LP token: %d ether", lptoken / 10 ** 18);
        lp.approve(address(lp), lptoken);

        oracleProvider.increaseVersion(entryPrice);

        uint256 lpTokenBefore = lp.balanceOf(address(this));
        uint256 usdcTokenBefore = usdc.balanceOf(address(this));

        logLP();

        ChromaticLPReceipt memory receipt = lp.removeLiquidity(lptoken, address(this));

        logLP();

        oracleProvider.increaseVersion(entryPrice);
        assertEq(true, lp.settle(receipt.id));
        uint256 lpTokenAfter = lp.balanceOf(address(this));

        console.log(
            "LP token \n - before: %d\n - after remove: %d",
            lpTokenBefore / 10 ** 18,
            lpTokenAfter / 10 ** 18
        );
        console.log(
            "Settlement token \n - before: %d\n - after remove: %d",
            usdcTokenBefore / 10 ** 18,
            usdc.balanceOf(address(this)) / 10 ** 18
        );
        logLP();
        // taker.closePosition(address(market), openinfo.id);

        // oracleProvider.increaseVersion(exitPrice);
        // (canExec, ) = lp.resolveRebalance();
        // assertEq(canExec, false);

        // market.settleAll();

        // vm.expectEmit(true, true, false, true, taker.getAccount());
        // emit ClaimPosition(
        //     address(market),
        //     openinfo.id,
        //     uint256(entryPrice),
        //     uint256(exitPrice),
        //     (openinfo.qty * (exitPrice - entryPrice)) / 10 ** 18,
        //     0,
        //     CLAIM_USER
        // );
        // taker.claimPosition(address(market), openinfo.id);

        // uint256 balanceAfter = usdc.balanceOf(taker.getAccount());
        // console.log("balance before and after", balanceBefore / 10 ** 18, balanceAfter / 10 ** 18);
        // (canExec, ) = lp.resolveRebalance();
        // assertEq(canExec, true);

        // lp.rebalance();
    }
}
