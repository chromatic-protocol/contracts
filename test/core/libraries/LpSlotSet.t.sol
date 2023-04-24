// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {QTY_PRECISION, LEVERAGE_PRECISION} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotMargin} from "@usum/core/libraries/LpSlotMargin.sol";
import {LpSlotSet} from "@usum/core/libraries/LpSlotSet.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";

contract LpSlotSetTest is Test {
    using SafeCast for uint256;

    uint256 private constant PRICE_PRECISION = 10 ** 8;

    IOracleProvider provider;
    IInterestCalculator calculator;
    LpSlotSet slotSet;

    function setUp() public {
        provider = IOracleProvider(address(1));
        calculator = IInterestCalculator(address(2));

        slotSet._longSlots[1].total = 1000 ether;
        slotSet._longSlots[2].total = 1000 ether;
    }

    function testPrepareSlotMargins() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();

        slotSet.prepareSlotMargins(position, 1500 ether);

        assertEq(position.leveragedQty(ctx), 1500 ether);
        assertEq(position._slotMargins[0].tradingFeeRate, 1);
        assertEq(position._slotMargins[0].amount, 1000 ether);
        assertEq(position._slotMargins[0].tradingFee(), 0.1 ether);
        assertEq(position._slotMargins[1].tradingFeeRate, 2);
        assertEq(position._slotMargins[1].amount, 500 ether);
        assertEq(position._slotMargins[1].tradingFee(), 0.1 ether);
    }

    function testAcceptOpenPosition() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        slotSet.prepareSlotMargins(position, 1500 ether);

        slotSet.acceptOpenPosition(ctx, position);

        assertEq(slotSet._minAvailableFeeRateLong, 2);
        assertEq(slotSet._longSlots[1].total, 1000.1 ether);
        assertEq(slotSet._longSlots[1].balance(), 0.1 ether);
        assertEq(slotSet._longSlots[2].total, 1000.1 ether);
        assertEq(slotSet._longSlots[2].balance(), 500.1 ether);
    }

    function testCloseOpenPosition_whenSameRound() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        slotSet.prepareSlotMargins(position, 1500 ether);
        slotSet.acceptOpenPosition(ctx, position);

        ctx._currentVersionCache.version = 1;

        slotSet.acceptClosePosition(ctx, position, 0);

        assertEq(slotSet._minAvailableFeeRateLong, 1);
        assertEq(slotSet._longSlots[1].total, 1000.1 ether);
        assertEq(slotSet._longSlots[1].balance(), 1000.1 ether);
        assertEq(slotSet._longSlots[2].total, 1000.1 ether);
        assertEq(slotSet._longSlots[2].balance(), 1000.1 ether);
    }

    function testCloseOpenPosition_whenNextRoundWithTakerProfit() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        slotSet.prepareSlotMargins(position, 1500 ether);
        slotSet.acceptOpenPosition(ctx, position);

        ctx._currentVersionCache = OracleVersion({
            version: 2,
            timestamp: 2,
            price: int256(110 * PRICE_PRECISION)
        });

        slotSet.acceptClosePosition(ctx, position, 150 ether);

        assertEq(slotSet._minAvailableFeeRateLong, 1);
        assertEq(slotSet._longSlots[1].total, 900.1 ether);
        assertEq(slotSet._longSlots[1].balance(), 900.1 ether);
        assertEq(slotSet._longSlots[2].total, 950.1 ether);
        assertEq(slotSet._longSlots[2].balance(), 950.1 ether);
    }

    function testCloseOpenPosition_whenNextRoundWithTakerLoss() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        slotSet.prepareSlotMargins(position, 1500 ether);
        slotSet.acceptOpenPosition(ctx, position);

        ctx._currentVersionCache = OracleVersion({
            version: 2,
            timestamp: 2,
            price: int256(90 * PRICE_PRECISION)
        });

        slotSet.acceptClosePosition(ctx, position, -150 ether);

        assertEq(slotSet._minAvailableFeeRateLong, 1);
        assertEq(slotSet._longSlots[1].total, 1100.1 ether);
        assertEq(slotSet._longSlots[1].balance(), 1100.1 ether);
        assertEq(slotSet._longSlots[2].total, 1050.1 ether);
        assertEq(slotSet._longSlots[2].balance(), 1050.1 ether);
    }

    function testMint() public {
        LpContext memory ctx = _newLpContext();

        ctx._currentVersionCache = OracleVersion({
            version: 2,
            timestamp: 2,
            price: int256(90 * PRICE_PRECISION)
        });

        uint256 liquidity = slotSet.mint(ctx, 1, 100 ether, 1000 ether);

        assertEq(liquidity, 100 ether);
        assertEq(slotSet._longSlots[1].total, 1100 ether);
    }

    function testBurn() public {
        LpContext memory ctx = _newLpContext();

        ctx._currentVersionCache = OracleVersion({
            version: 2,
            timestamp: 2,
            price: int256(90 * PRICE_PRECISION)
        });

        uint256 amount = slotSet.burn(ctx, 1, 100 ether, 1000 ether);

        assertEq(amount, 100 ether);
        assertEq(slotSet._longSlots[1].total, 900 ether);
    }

    function _newLpContext() private view returns (LpContext memory) {
        return
            LpContext({
                oracleProvider: provider,
                interestCalculator: calculator,
                tokenPrecision: 10 ** 18,
                _pricePrecision: PRICE_PRECISION,
                _currentVersionCache: OracleVersion(0, 0, 0)
            });
    }

    function _newPosition() private pure returns (Position memory) {
        return
            Position({
                id:1,
                oracleVersion: 1,
                qty: int224(150 * QTY_PRECISION.toInt256()),
                leverage: uint32(10 * LEVERAGE_PRECISION),
                takerMargin: 150 ether,
                timestamp: 1,
                owner: address(0),
                _slotMargins: new LpSlotMargin[](0)
            });
    }
}
