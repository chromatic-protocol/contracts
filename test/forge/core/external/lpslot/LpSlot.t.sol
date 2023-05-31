// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Fixed18Lib} from "@equilibria/root/number/types/Fixed18.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlot, LpSlotLib} from "@usum/core/external/lpslot/LpSlot.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMVault} from "@usum/core/interfaces/IUSUMVault.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IUSUMLpToken} from "@usum/core/interfaces/IUSUMLpToken.sol";
import {USUMLpToken} from "@usum/core/USUMLpToken.sol";

contract LpSlotTest is Test {
    using SafeCast for uint256;
    using LpSlotLib for LpSlot;

    IOracleProvider provider;
    IUSUMVault vault;
    IUSUMMarket market;
    IUSUMLpToken lpToken;
    LpSlot slot;

    function setUp() public {
        provider = IOracleProvider(address(1));
        vault = IUSUMVault(address(2));
        market = IUSUMMarket(address(3));
        lpToken = new USUMLpToken();

        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.getPendingSlotShare.selector),
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

        slot._liquidity.total = 20000 ether;
    }

    function testAcceptAddLiquidity() public {
        LpContext memory ctx = _newLpContext();

        // oracle version 2
        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = Fixed18Lib.from(90);
        slot.acceptAddLiquidity(ctx, 100 ether);
        assertEq(slot.liquidity(), 20000 ether);

        // oracle version 3
        ctx._currentVersionCache.version = 3;
        ctx._currentVersionCache.timestamp = 3;
        slot.settle(ctx);
        assertEq(slot.liquidity(), 20100 ether);
    }

    function testAcceptRemoveLiquidity() public {
        LpContext memory ctx = _newLpContext();

        // oracle version 2
        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = Fixed18Lib.from(90);
        slot.acceptRemoveLiquidity(ctx, 100 ether);
        assertEq(slot.liquidity(), 20000 ether);

        // oracle version 3
        ctx._currentVersionCache.version = 3;
        ctx._currentVersionCache.timestamp = 3;
        slot.settle(ctx);
        assertEq(slot.liquidity(), 19900 ether);
    }

    function testValue() public {
        LpContext memory ctx = _newLpContext();

        slot._position.totalLeveragedQty = -150 ether;
        slot._position.totalEntryAmount = 15000 ether; // oraclePrice 100
        slot._position._totalMakerMargin = 15000 ether;
        slot._position._totalTakerMargin = 15000 ether;
        slot._position._accruedInterest.accumulatedAt = 1;
        slot._position._accruedInterest.accumulatedAmount = 0.1 ether;
        slot._position._pending.openVersion = 1;
        slot._position._pending.totalLeveragedQty = -10 ether;
        slot._position._pending.totalMakerMargin = 1000 ether;
        slot._position._pending.totalTakerMargin = 1000 ether;
        slot._position._pending.accruedInterest.accumulatedAt = 1;

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
            address(market),
            abi.encodeWithSelector(0x05e1bd8c, 15000 ether, 1, 3),
            abi.encode(0.01 ether)
        );
        vm.mockCall(
            address(market),
            abi.encodeWithSelector(0x05e1bd8c, 1000 ether, 1, 3),
            abi.encode(0.001 ether)
        );

        uint256 value = slot.value(ctx);
        assertEq(value, 21501.111 ether);
    }

    function _newLpContext() private view returns (LpContext memory) {
        IOracleProvider.OracleVersion memory _currentVersionCache;
        return
            LpContext({
                oracleProvider: provider,
                vault: vault,
                lpToken: lpToken,
                market: market,
                tokenPrecision: 1e18,
                _currentVersionCache: _currentVersionCache
            });
    }
}
