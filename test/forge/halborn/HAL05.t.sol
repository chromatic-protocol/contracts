// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./Deploy.sol";

contract HAL05 is Deploy {
    MockFlashloanV2 public contract_MockFlashloanV2;
    MockChromaticAccountV2 public contract_MockChromaticAccountV2;

    function setUp() public override {
        super.setUp();

        vm.startPrank(user1, user1);

        deal(address(contract_TestSettlementToken), user1, 3000 ether);
        IERC20(contract_TestSettlementToken).approve(
            address(contract_ChromaticRouter),
            type(uint256).max
        );
        contract_ChromaticRouter.addLiquidity(
            address(contract_ChromaticMarket),
            1,
            3000 ether,
            user1
        );

        contract_PriceFeedMock.setRoundData(1e18);
        MarketSettleFacet(address(contract_ChromaticMarket)).settleAll();

        vm.startPrank(owner, owner);

        contract_MockFlashloanV2 = new MockFlashloanV2(
            address(contract_ChromaticVault),
            address(contract_TestSettlementToken),
            address(contract_ChromaticRouter),
            address(contract_ChromaticMarket)
        );

        contract_MockChromaticAccountV2 = new MockChromaticAccountV2();
        contract_MockChromaticAccountV2.initialize(
            owner,
            address(contract_ChromaticRouter),
            address(contract_ChromaticMarketFactory),
            address(contract_MockFlashloanV2)
        );

        deal(address(contract_TestSettlementToken), address(contract_MockFlashloanV2), 150 ether);
    }

    function test_addLiquidity() public {
        vm.expectRevert(ChromaticVault.TradingLockAlreadyAcquired.selector);
        contract_MockChromaticAccountV2.addLiquidity(address(contract_ChromaticMarket));
    }
}
