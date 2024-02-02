// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {MarketLiquidityFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacetBase.sol";
import {BaseSetup} from "../BaseSetup.sol";
import "forge-std/console.sol";
import "forge-std/StdStyle.sol";

contract LiquidityTest is BaseSetup {
    address user1 = address(0x111111);
    address user2 = address(0x222222);
    address user3 = address(0x333333);
    address user4 = address(0x444444);

    function setUp() public override {
        super.setUp();
    }

    function test_claimLiquidityBatch() public {
        console.log(StdStyle.yellow("\n\ntest_claimLiquidityBatch()"));
        console.log(StdStyle.yellow("__________________________\n"));

        deal(address(ctst), user1, 1000e18);
        deal(address(ctst), user2, 2000e18);
        deal(address(ctst), user3, 3000e18);
        deal(address(ctst), user4, 150e18);

        vm.startPrank(user1, user1);
        console.log(
            StdStyle.yellow(
                "\nUSER1(%s) CALLS < contract_TestSettlementToken.approve(contract_ChromaticRouter, 1000e18) >"
            ),
            user1
        );
        ctst.approve(address(router), 1000e18);
        // add liquidity $1000 to 0.01% long bin
        console.log(
            StdStyle.yellow(
                "\nUSER1(%s) CALLS < contract_ChromaticRouter.addLiquidity(contract_ChromaticMarket, 1, 1000e18, user1) >"
            ),
            user1
        );
        router.addLiquidity(address(market), int16(1), 1000e18, user1);
        vm.stopPrank();

        vm.startPrank(user2, user2);
        console.log(
            StdStyle.yellow(
                "\nUSER2(%s) CALLS < contract_TestSettlementToken.approve(contract_ChromaticRouter, 2000e18) >"
            ),
            user2
        );
        ctst.approve(address(router), 2000e18);
        // add liquidity $2000 to 0.01% long bin
        console.log(
            StdStyle.yellow(
                "\nUSER2(%s) CALLS < contract_ChromaticRouter.addLiquidity(contract_ChromaticMarket, 1, 2000e18, user2) >"
            ),
            user2
        );
        router.addLiquidity(address(market), int16(1), 2000e18, user2);
        vm.stopPrank();

        console.log(StdStyle.yellow("\n< contract_PriceFeedMock.setRoundData(1e18) >"));
        oracleProvider.increaseVersion(1e18);

        vm.startPrank(user1, user1);
        /**
            function claimLiquidityBatch(address market, uint256[] calldata _receiptIds) 
        */
        console.log(
            StdStyle.red("contract_CLBToken.balanceOf(user1, 1) -> %s"),
            market.clbToken().balanceOf(user1, 1)
        );
        console.log(
            StdStyle.red("contract_CLBToken.balanceOf(user2, 1) -> %s"),
            market.clbToken().balanceOf(user2, 1)
        );
        uint256[] memory _receiptIds = new uint256[](2);
        _receiptIds[0] = 1;
        _receiptIds[1] = 1;
        console.log(
            StdStyle.yellow(
                "\nUSER1(%s) CALLS < contract_ChromaticRouter.claimLiquidityBatch(contract_ChromaticMarket, [1,1]) >"
            ),
            user1
        );
        vm.expectRevert(MarketLiquidityFacetBase.NotExistLpReceipt.selector);
        router.claimLiquidityBatch(address(market), _receiptIds);
        console.log(
            StdStyle.red("contract_CLBToken.balanceOf(user1, 1) -> %s"),
            market.clbToken().balanceOf(user1, 1)
        );
        console.log(
            StdStyle.red("contract_CLBToken.balanceOf(user2, 1) -> %s"),
            market.clbToken().balanceOf(user2, 1)
        );
        vm.stopPrank();
    }
}
