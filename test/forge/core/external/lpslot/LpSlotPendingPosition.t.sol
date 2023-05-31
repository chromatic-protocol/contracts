// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Fixed18} from "@equilibria/root/number/types/Fixed18.sol";
import {UFixed18} from "@equilibria/root/number/types/UFixed18.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotPendingPosition, LpSlotPendingPositionLib} from "@usum/core/external/lpslot/LpSlotPendingPosition.sol";
import {PositionParam} from "@usum/core/external/lpslot/PositionParam.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMVault} from "@usum/core/interfaces/IUSUMVault.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";

contract LpSlotPendingPositionTest is Test {
    using SafeCast for uint256;
    using LpSlotPendingPositionLib for LpSlotPendingPosition;

    IOracleProvider provider;
    IUSUMVault vault;
    IUSUMMarket market;
    LpSlotPendingPosition pending;

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
    }

    function testOnOpenPosition_WhenEmpty() public {
        PositionParam memory param = _newPositionParam();

        pending.onOpenPosition(param);

        assertEq(pending.openVersion, param.openVersion);
        assertEq(pending.totalLeveragedQty, param.leveragedQty);
        assertEq(pending.totalMakerMargin, param.makerMargin);
        assertEq(pending.totalTakerMargin, param.takerMargin);
    }

    function testOnOpenPosition_Normal() public {
        pending.openVersion = 1;
        pending.totalLeveragedQty = 10;

        PositionParam memory param = _newPositionParam();

        pending.onOpenPosition(param);

        assertEq(pending.openVersion, param.openVersion);
        assertEq(pending.totalLeveragedQty, param.leveragedQty + 10);
        assertEq(pending.totalMakerMargin, param.makerMargin);
        assertEq(pending.totalTakerMargin, param.takerMargin);
    }

    function testOnOpenPosition_InvalidOracleVersion() public {
        pending.openVersion = 1;
        pending.totalLeveragedQty = 10;

        PositionParam memory param = _newPositionParam();
        param.openVersion = 2;

        vm.expectRevert(bytes("IOV"));
        pending.onOpenPosition(param);
    }

    function testOnOpenPosition_InvalidOpenPositionQty() public {
        pending.openVersion = 1;
        pending.totalLeveragedQty = 10;

        PositionParam memory param = _newPositionParam().inverse();

        vm.expectRevert(bytes("IPQ"));
        pending.onOpenPosition(param);
    }

    function testOnClosePosition_WhenEmpty() public {
        pending.openVersion = 1;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        vm.expectRevert(bytes("IPQ"));
        pending.onClosePosition(ctx, param);
    }

    function testOnClosePosition_Normal() public {
        pending.openVersion = 1;
        pending.totalLeveragedQty = 50;
        pending.totalMakerMargin = 50;
        pending.totalTakerMargin = 10;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        pending.onClosePosition(ctx, param);

        assertEq(pending.openVersion, param.openVersion);
        assertEq(pending.totalLeveragedQty, 0);
        assertEq(pending.totalMakerMargin, 0);
        assertEq(pending.totalTakerMargin, 0);
    }

    function testOnClosePosition_InvalidOracleVersion() public {
        pending.openVersion = 1;
        pending.totalLeveragedQty = 50;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();
        param.openVersion = 2;

        vm.expectRevert(bytes("IOV"));
        pending.onClosePosition(ctx, param);
    }

    function testOnClosePosition_InvalidClosePositionQty() public {
        pending.openVersion = 1;
        pending.totalLeveragedQty = 10;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        vm.expectRevert(bytes("IPQ"));
        pending.onClosePosition(ctx, param);
    }

    function testEntryPrice_UsingProviderCall() public {
        pending.openVersion = 1;
        pending.totalLeveragedQty = 10;

        LpContext memory ctx = _newLpContext();
        ctx._currentVersionCache.version = 10;
        ctx._currentVersionCache.timestamp = 10;
        ctx._currentVersionCache.price = Fixed18.wrap(1200);

        IOracleProvider.OracleVersion memory _ov;
        _ov.version = 2;
        _ov.timestamp = 2;
        _ov.price = Fixed18.wrap(1100);
        vm.mockCall(
            address(provider),
            abi.encodeWithSelector(provider.atVersion.selector, 2),
            abi.encode(_ov)
        );

        vm.expectCall(address(provider), abi.encodeWithSelector(provider.atVersion.selector, 2));
        UFixed18 entryPrice = pending.entryPrice(ctx);

        assertEq(UFixed18.unwrap(entryPrice), 1100);
    }

    function _newLpContext() private view returns (LpContext memory ctx) {
        ctx.market = market;
        ctx.tokenPrecision = 10 ** 6;
    }

    function _newPositionParam() private pure returns (PositionParam memory p) {
        p.openVersion = 1;
        p.leveragedQty = 50;
        p.takerMargin = 10;
        p.makerMargin = 50;
        p.openTimestamp = 1;
    }
}
