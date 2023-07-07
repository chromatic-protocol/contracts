// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Fixed18} from "@equilibria/root/number/types/Fixed18.sol";
import {UFixed18} from "@equilibria/root/number/types/UFixed18.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {PositionUtil} from "@chromatic-protocol/contracts/core/libraries/PositionUtil.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {BinPendingPosition, BinPendingPositionLib} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinPendingPosition.sol";
import {PositionParam} from "@chromatic-protocol/contracts/core/libraries/liquidity/PositionParam.sol";
import {IInterestCalculator} from "@chromatic-protocol/contracts/core/interfaces/IInterestCalculator.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {CLBToken} from "@chromatic-protocol/contracts/core/CLBToken.sol";

contract BinPendingPositionTest is Test {
    using SafeCast for uint256;
    using BinPendingPositionLib for BinPendingPosition;

    IOracleProvider provider;
    IInterestCalculator interestCalculator;
    IChromaticVault vault;
    IChromaticMarket market;
    ICLBToken clbToken;
    BinPendingPosition pending;

    function setUp() public {
        provider = IOracleProvider(address(1));
        interestCalculator = IInterestCalculator(address(2));
        vault = IChromaticVault(address(3));
        market = IChromaticMarket(address(4));
        clbToken = new CLBToken();

        vm.mockCall(
            address(interestCalculator),
            abi.encodeWithSelector(interestCalculator.calculateInterest.selector),
            abi.encode(0)
        );
    }

    function testOnOpenPosition_WhenEmpty() public {
        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        pending.onOpenPosition(ctx, param);

        assertEq(pending.openVersion, param.openVersion);
        assertEq(pending.totalLeveragedQty, param.leveragedQty);
        assertEq(pending.totalMakerMargin, param.makerMargin);
        assertEq(pending.totalTakerMargin, param.takerMargin);
    }

    function testOnOpenPosition_Normal() public {
        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        pending.openVersion = 1;
        pending.totalLeveragedQty = 10;

        pending.onOpenPosition(ctx, param);

        assertEq(pending.openVersion, param.openVersion);
        assertEq(pending.totalLeveragedQty, param.leveragedQty + 10);
        assertEq(pending.totalMakerMargin, param.makerMargin);
        assertEq(pending.totalTakerMargin, param.takerMargin);
    }

    function testOnOpenPosition_InvalidOracleVersion() public {
        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        pending.openVersion = 1;
        pending.totalLeveragedQty = 10;
        param.openVersion = 2;

        vm.expectRevert(bytes("IOV"));
        pending.onOpenPosition(ctx, param);
    }

    function testOnOpenPosition_InvalidOpenPositionQty() public {
        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam().inverse();

        pending.openVersion = 1;
        pending.totalLeveragedQty = 10;

        vm.expectRevert(bytes("IPQ"));
        pending.onOpenPosition(ctx, param);
    }

    function testOnClosePosition_WhenEmpty() public {
        pending.openVersion = 1;

        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        vm.expectRevert(bytes("IPQ"));
        pending.onClosePosition(ctx, param);
    }

    function testOnClosePosition_Normal() public {
        LpContext memory ctx = _newLpContext();
        PositionParam memory param = _newPositionParam();

        pending.openVersion = 1;
        pending.totalLeveragedQty = 50;
        pending.totalMakerMargin = 50;
        pending.totalTakerMargin = 10;

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

    function _newLpContext() private view returns (LpContext memory) {
        IOracleProvider.OracleVersion memory _currentVersionCache;
        return
            LpContext({
                oracleProvider: provider,
                interestCalculator: interestCalculator,
                vault: vault,
                clbToken: clbToken,
                market: address(market),
                settlementToken: address(0),
                tokenPrecision: 1e6,
                _currentVersionCache: _currentVersionCache
            });
    }

    function _newPositionParam() private pure returns (PositionParam memory p) {
        p.openVersion = 1;
        p.leveragedQty = 50;
        p.takerMargin = 10;
        p.makerMargin = 50;
        p.openTimestamp = 1;
    }
}
