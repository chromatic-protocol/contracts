// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpSlotPendingPosition, LpSlotPendingPositionLib} from "@usum/core/libraries/LpSlotPendingPosition.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";

contract LpSlotPendingPositionTest is Test {
    using SafeCast for uint256;
    using LpSlotPendingPositionLib for LpSlotPendingPosition;

    IOracleProvider provider;
    IInterestCalculator calculator;
    LpSlotPendingPosition pending;

    function setUp() public {
        provider = IOracleProvider(address(1));
        calculator = IInterestCalculator(address(2));
    }

    function testOpenPosition_WhenEmpty() public {
        PositionParam memory param = _newPositionParam();

        pending.openPosition(param);

        assertEq(pending.oracleVersion, param.oracleVersion);
        assertEq(pending.totalLeveragedQty, param.leveragedQty);
        assertEq(pending.totalMakerMargin, param.makerMargin);
        assertEq(pending.totalTakerMargin, param.takerMargin);
    }

    function testOpenPosition_Normal() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        PositionParam memory param = _newPositionParam();

        pending.openPosition(param);

        assertEq(pending.oracleVersion, param.oracleVersion);
        assertEq(pending.totalLeveragedQty, param.leveragedQty + 10);
        assertEq(pending.totalMakerMargin, param.makerMargin);
        assertEq(pending.totalTakerMargin, param.takerMargin);
    }

    function testOpenPosition_InvalidOracleVersion() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        PositionParam memory param = _newPositionParam();
        param.oracleVersion = 2;

        vm.expectRevert(LpSlotPendingPositionLib.InvalidOracleVersion.selector);
        pending.openPosition(param);
    }

    function testOpenPosition_InvalidOpenPositionQty() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        PositionParam memory param = _newPositionParam().clone();
        param.leveragedQty *= -1;

        vm.expectRevert(PositionUtil.InvalidPositionQty.selector);
        pending.openPosition(param);
    }

    function testClosePosition_WhenEmpty() public {
        pending.oracleVersion = 1;

        PositionParam memory param = _newPositionParam();

        vm.expectRevert(PositionUtil.InvalidPositionQty.selector);
        pending.closePosition(param);
    }

    function testClosePosition_Normal() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 50;
        pending.totalMakerMargin = 50;
        pending.totalTakerMargin = 10;

        PositionParam memory param = _newPositionParam();

        pending.closePosition(param);

        assertEq(pending.oracleVersion, param.oracleVersion);
        assertEq(pending.totalLeveragedQty, 0);
        assertEq(pending.totalMakerMargin, 0);
        assertEq(pending.totalTakerMargin, 0);
    }

    function testClosePosition_InvalidOracleVersion() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 50;

        PositionParam memory param = _newPositionParam();
        param.oracleVersion = 2;

        vm.expectRevert(LpSlotPendingPositionLib.InvalidOracleVersion.selector);
        pending.closePosition(param);
    }

    function testClosePosition_InvalidClosePositionQty() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        PositionParam memory param = _newPositionParam(); // close using leveragedQty = 50

        vm.expectRevert(PositionUtil.InvalidPositionQty.selector);
        pending.closePosition(param);
    }

    function testEntryPrice_AtCurrentVersion() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        uint256 entryPrice = pending.entryPrice(
            provider,
            OracleVersion({version: 2, timestamp: 2, price: 1000})
        );

        assertEq(entryPrice, 1000);
    }

    function testEntryPrice_UsingProviderCall() public {
        pending.oracleVersion = 1;
        pending.totalLeveragedQty = 10;

        vm.mockCall(
            address(provider),
            abi.encodeWithSelector(IOracleProvider.atVersion.selector, 2),
            abi.encode(OracleVersion({version: 2, timestamp: 2, price: 1100}))
        );

        vm.expectCall(
            address(provider),
            abi.encodeWithSelector(IOracleProvider.atVersion.selector, 2)
        );
        uint256 entryPrice = pending.entryPrice(
            provider,
            OracleVersion({version: 10, timestamp: 10, price: 1000})
        );

        assertEq(entryPrice, 1100);
    }

    function _newPositionParam() private view returns (PositionParam memory) {
        return
            PositionParam({
                oracleProvider: provider,
                interestCalculator: calculator,
                oracleVersion: 1,
                leveragedQty: 50,
                takerMargin: 10,
                makerMargin: 50,
                timestamp: 1,
                _settleVersionCache: OracleVersion(0, 0, 0),
                _currentVersionCache: OracleVersion(0, 0, 0)
            });
    }
}
