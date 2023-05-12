// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlot, LpSlotLib} from "@usum/core/external/lpslot/LpSlot.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMVault} from "@usum/core/interfaces/IUSUMVault.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";

contract LpSlotTest is Test {
    using SafeCast for uint256;
    using LpSlotLib for LpSlot;

    uint256 private constant PRICE_PRECISION = 10 ** 8;

    IOracleProvider provider;
    IUSUMVault vault;
    IUSUMMarket market;
    LpSlot slot;

    function setUp() public {
        provider = IOracleProvider(address(1));
        vault = IUSUMVault(address(2));
        market = IUSUMMarket(address(3));

        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.getPendingSlotShare.selector),
            abi.encode(0)
        );

        vm.mockCall(
            address(market),
            abi.encodeWithSelector(market.oracleProvider.selector),
            abi.encode(provider)
        );
        vm.mockCall(
            address(market),
            abi.encodeWithSelector(market.vault.selector),
            abi.encode(vault)
        );

        slot.total = 20000 ether;
    }

    function testAddLiquidity() public {
        LpContext memory ctx = _newLpContext();

        ctx._currentVersionCache = OracleVersion({
            version: 2,
            timestamp: 2,
            price: int256(90 * PRICE_PRECISION)
        });

        uint256 liquidity = slot.addLiquidity(ctx, 100 ether, 20000 ether);

        assertEq(liquidity, 100 ether);
        assertEq(slot.total, 20100 ether);
    }

    function testRemoveLiquidity() public {
        LpContext memory ctx = _newLpContext();

        ctx._currentVersionCache = OracleVersion({
            version: 2,
            timestamp: 2,
            price: int256(90 * PRICE_PRECISION)
        });

        uint256 amount = slot.removeLiquidity(ctx, 100 ether, 20000 ether);

        assertEq(amount, 100 ether);
        assertEq(slot.total, 19900 ether);
    }

    function testValue() public {
        LpContext memory ctx = _newLpContext();

        slot._position.totalLeveragedQty = -150 ether;
        slot._position.totalEntryAmount = 15000 ether; // oraclePrice 100
        slot._position._totalMakerMargin = 15000 ether;
        slot._position._totalTakerMargin = 15000 ether;
        slot._position._accruedInterest.accumulatedAt = 1;
        slot._position._accruedInterest.accumulatedAmount = 0.1 ether;
        slot._position._pending.oracleVersion = 1;
        slot._position._pending.totalLeveragedQty = -10 ether;
        slot._position._pending.totalMakerMargin = 1000 ether;
        slot._position._pending.totalTakerMargin = 1000 ether;
        slot._position._pending.accruedInterest.accumulatedAt = 1;

        vm.warp(3);
        ctx._currentVersionCache = OracleVersion({
            version: 3,
            timestamp: 3,
            price: int256(90 * PRICE_PRECISION)
        });

        vm.mockCall(
            address(provider),
            abi.encodeWithSelector(IOracleProvider.atVersion.selector, 2),
            abi.encode(
                OracleVersion({
                    version: 2,
                    timestamp: 2,
                    price: int256(100 * PRICE_PRECISION)
                })
            )
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
        return
            LpContext({
                market: market,
                tokenPrecision: 10 ** 18,
                _pricePrecision: PRICE_PRECISION,
                _currentVersionCache: OracleVersion(0, 0, 0)
            });
    }
}
