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

    function testOpenPosition_WhenEmpty() public {
        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        pending.openPosition(ctx, param);

        assertEq(pending.oracleVersion, param.oracleVersion);
        assertEq(pending.totalLeveragedQty, param.leveragedQty);
        assertEq(pending.totalMakerMargin, param.makerMargin);
        assertEq(pending.totalTakerMargin, param.takerMargin);
    }

    function testOpenPosition_Normal() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        pending.openPosition(ctx, param);

        assertEq(pending.oracleVersion, param.oracleVersion);
        assertEq(pending.totalLeveragedQty, param.leveragedQty + 10);
        assertEq(pending.totalMakerMargin, param.makerMargin);
        assertEq(pending.totalTakerMargin, param.takerMargin);
    }

    function testOpenPosition_InvalidOracleVersion() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();
        param.oracleVersion = 2;

        vm.expectRevert(bytes("IOV"));
        pending.openPosition(ctx, param);
    }

    function testOpenPosition_InvalidOpenPositionQty() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam().inverse();

        vm.expectRevert(bytes("IPQ"));
        pending.openPosition(ctx, param);
    }

    function testClosePosition_WhenEmpty() public {
        pending.oracleVersion = 1;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        vm.expectRevert(bytes("IPQ"));
        pending.closePosition(ctx, param);
    }

    function testClosePosition_Normal() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 50;
        pending.totalMakerMargin = 50;
        pending.totalTakerMargin = 10;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        pending.closePosition(ctx, param);

        assertEq(pending.oracleVersion, param.oracleVersion);
        assertEq(pending.totalLeveragedQty, 0);
        assertEq(pending.totalMakerMargin, 0);
        assertEq(pending.totalTakerMargin, 0);
    }

    function testClosePosition_InvalidOracleVersion() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 50;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();
        param.oracleVersion = 2;

        vm.expectRevert(bytes("IOV"));
        pending.closePosition(ctx, param);
    }

    function testClosePosition_InvalidClosePositionQty() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        vm.expectRevert(bytes("IPQ"));
        pending.closePosition(ctx, param);
    }

    function testEntryPrice_UsingProviderCall() public {
        pending.oracleVersion = 1;
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

        vm.expectCall(
            address(provider),
            abi.encodeWithSelector(provider.atVersion.selector, 2)
        );
        UFixed18 entryPrice = pending.entryPrice(ctx);

        assertEq(UFixed18.unwrap(entryPrice), 1100);
    }

    function _newLpContext() private view returns (LpContext memory ctx) {
        ctx.market = market;
        ctx.tokenPrecision = 10 ** 6;
    }

    function _newPositionParam() private pure returns (PositionParam memory p) {
        p.oracleVersion = 1;
        p.leveragedQty = 50;
        p.takerMargin = 10;
        p.makerMargin = 50;
        p.timestamp = 1;
    }
}
