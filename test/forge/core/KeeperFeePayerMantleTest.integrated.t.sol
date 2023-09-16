// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {KeeperFeePayer} from "@chromatic-protocol/contracts/core/KeeperFeePayer.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IWETH9, IERC20} from "@chromatic-protocol/contracts/core/interfaces/IWETH9.sol";

/** is IChromaticMarketFactory */
contract ChromaticMarketFactoryMock {
    // add this to be excluded from coverage report
    function test() public {}

    address owner;

    constructor() {
        owner = msg.sender;
    }

    function getUniswapFeeTier(address) external pure returns (uint24) {
        /**
         * Mantle Mainnet USDC - WETH fee
         * 10000 2500 500 100
         */
        return 10000;
    }

    function dao() external view returns (address) {
        return owner;
    }
}

// forge test --match-test 'payKeeperFeeTest' -vv
contract KeeperFeePayerMantleTest is Test {
    event OracleVersionUpdated(uint256 newVersion, uint256 timestamp, int256 price);

    string MANTLE_RPC_URL = "https://rpc.mantle.xyz/";
    KeeperFeePayer keeperFeePayer;
    // mantle mainnet only
    address AGNI_ROUTER = 0x319B69888b0d11cEC22caA5034e25FfFBDc88421;
    IWETH9 WETH = IWETH9(address(0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8));
    ISwapRouter swapRouter = ISwapRouter(AGNI_ROUTER);
    IERC20 USDC = IERC20(address(0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9));

    address alice = makeAddr("alice");
    address keeper = makeAddr("keeper");

    function setUp() public {
        uint256 forkId = vm.createFork(MANTLE_RPC_URL);
        vm.selectFork(forkId);
        ChromaticMarketFactoryMock factoryMock = new ChromaticMarketFactoryMock();
        keeperFeePayer = new KeeperFeePayer(
            IChromaticMarketFactory(address(factoryMock)),
            swapRouter,
            WETH
        );
        keeperFeePayer.approveToRouter(address(USDC), true);
    }

    function testPayKeeperFee() public {
        uint256 usdcBeginAmount = 10000 ether;
        uint256 amountOut = 3 ether;
        deal(address(USDC), (address(alice)), usdcBeginAmount);
        assertEq(USDC.balanceOf(alice), usdcBeginAmount);

        vm.startPrank(alice);

        emit log_named_uint("before keeper balance", keeper.balance);
        emit log_named_uint("before alice usdc balance", USDC.balanceOf(alice));

        USDC.transfer(address(keeperFeePayer), usdcBeginAmount);

        assertEq(USDC.balanceOf(address(keeperFeePayer)), usdcBeginAmount);
        assertEq(keeper.balance, 0);

        uint256 amountIn = keeperFeePayer.payKeeperFee(address(USDC), amountOut, keeper);

        emit log_named_uint("after keeper balance", keeper.balance);
        emit log_named_uint("after alice usdc balance", USDC.balanceOf(alice));

        assertEq(USDC.balanceOf(address(keeperFeePayer)), 0);
        assertEq(keeper.balance, amountOut);
        assertEq(USDC.balanceOf(alice), usdcBeginAmount - amountIn);
    }
}
