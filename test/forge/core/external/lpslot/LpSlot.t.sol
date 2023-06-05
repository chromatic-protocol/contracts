// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Fixed18Lib} from "@equilibria/root/number/types/Fixed18.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {LiquidityBin, LiquidityBinLib} from "@chromatic/core/external/lpslot/LiquidityBin.sol";
import {IOracleProvider} from "@chromatic/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@chromatic/core/interfaces/IInterestCalculator.sol";
import {IChromaticVault} from "@chromatic/core/interfaces/IChromaticVault.sol";
import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic/core/interfaces/ICLBToken.sol";
import {CLBToken} from "@chromatic/core/CLBToken.sol";

contract LiquidityBinTest is Test {
    using SafeCast for uint256;
    using LiquidityBinLib for LiquidityBin;

    IOracleProvider provider;
    IInterestCalculator interestCalculator;
    IChromaticVault vault;
    IChromaticMarket market;
    ICLBToken clbToken;
    address settlementToken;
    LiquidityBin bin;

    function setUp() public {
        provider = IOracleProvider(address(1));
        interestCalculator = IInterestCalculator(address(2));
        vault = IChromaticVault(address(3));
        market = IChromaticMarket(address(4));
        settlementToken = address(5);
        clbToken = new CLBToken();

        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.getPendingBinShare.selector),
            abi.encode(0)
        );

        vm.mockCall(
            address(market),
            abi.encodeWithSelector(IERC1155Receiver(address(market)).onERC1155Received.selector),
            abi.encode(IERC1155Receiver(address(market)).onERC1155Received.selector)
        );
        vm.mockCall(
            address(market),
            abi.encodeWithSelector(
                IERC1155Receiver(address(market)).onERC1155BatchReceived.selector
            ),
            abi.encode(IERC1155Receiver(address(market)).onERC1155BatchReceived.selector)
        );

        bin.initialize(1);
        bin._liquidity.total = 20000 ether;

        clbToken.mint(address(market), 1, 20000 ether, bytes(""));
    }

    function testAcceptAddLiquidity() public {
        LpContext memory ctx = _newLpContext();

        // oracle version 2
        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = Fixed18Lib.from(90);
        bin.acceptAddLiquidity(ctx, 100 ether);
        assertEq(bin.liquidity(), 20000 ether);

        // oracle version 3
        ctx._currentVersionCache.version = 3;
        ctx._currentVersionCache.timestamp = 3;
        bin.settle(ctx);
        assertEq(bin.liquidity(), 20100 ether);
    }

    function testAcceptRemoveLiquidity() public {
        LpContext memory ctx = _newLpContext();

        // oracle version 2
        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = Fixed18Lib.from(90);
        bin.acceptRemoveLiquidity(ctx, 100 ether);
        assertEq(bin.liquidity(), 20000 ether);

        // oracle version 3
        ctx._currentVersionCache.version = 3;
        ctx._currentVersionCache.timestamp = 3;
        bin.settle(ctx);
        assertEq(bin.liquidity(), 19900 ether);
    }

    function testValue() public {
        LpContext memory ctx = _newLpContext();

        bin._position.totalLeveragedQty = -150 ether;
        bin._position.totalEntryAmount = 15000 ether; // oraclePrice 100
        bin._position._totalMakerMargin = 15000 ether;
        bin._position._totalTakerMargin = 15000 ether;
        bin._position._accruedInterest.accumulatedAt = 1;
        bin._position._accruedInterest.accumulatedAmount = 0.1 ether;
        bin._position._pending.openVersion = 1;
        bin._position._pending.totalLeveragedQty = -10 ether;
        bin._position._pending.totalMakerMargin = 1000 ether;
        bin._position._pending.totalTakerMargin = 1000 ether;
        bin._position._pending.accruedInterest.accumulatedAt = 1;

        vm.warp(3);
        ctx._currentVersionCache.version = 3;
        ctx._currentVersionCache.timestamp = 3;
        ctx._currentVersionCache.price = Fixed18Lib.from(90);

        IOracleProvider.OracleVersion memory _ov;
        _ov.version = 2;
        _ov.timestamp = 2;
        _ov.price = Fixed18Lib.from(100);
        vm.mockCall(
            address(provider),
            abi.encodeWithSelector(provider.atVersion.selector, 2),
            abi.encode(_ov)
        );
        vm.mockCall(
            address(interestCalculator),
            abi.encodeWithSelector(
                interestCalculator.calculateInterest.selector,
                settlementToken,
                15000 ether,
                1,
                3
            ),
            abi.encode(0.01 ether)
        );
        vm.mockCall(
            address(interestCalculator),
            abi.encodeWithSelector(
                interestCalculator.calculateInterest.selector,
                settlementToken,
                1000 ether,
                1,
                3
            ),
            abi.encode(0.001 ether)
        );

        uint256 value = bin.value(ctx);
        assertEq(value, 21501.111 ether);
    }

    function _newLpContext() private view returns (LpContext memory) {
        IOracleProvider.OracleVersion memory _currentVersionCache;
        return
            LpContext({
                oracleProvider: provider,
                interestCalculator: interestCalculator,
                vault: vault,
                clbToken: clbToken,
                market: address(market),
                settlementToken: settlementToken,
                tokenPrecision: 1e18,
                _currentVersionCache: _currentVersionCache
            });
    }
}
