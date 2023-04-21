// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotPosition, LpSlotPositionLib} from "@usum/core/libraries/LpSlotPosition.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";

contract LpSlotPositionTest is Test {
    using LpSlotPositionLib for LpSlotPosition;

    IOracleProvider provider;
    IInterestCalculator calculator;
    LpSlotPosition position;

    function setUp() public {
        provider = IOracleProvider(address(1));
        calculator = IInterestCalculator(address(2));
    }

    function testClosePosition() public {
        position.totalLeveragedQty = 100;
        position.totalEntryAmount = 200000;
        position._totalMakerMargin = 100;
        position._totalTakerMargin = 100;

        LpContext memory ctx = _newLpContext();
        ctx._currentVersionCache = OracleVersion({
            version: 3,
            timestamp: 3,
            price: 2100
        });

        PositionParam memory param = _newPositionParam();
        param._settleVersionCache = OracleVersion({
            version: 2,
            timestamp: 2,
            price: 2000
        });

        position.closePosition(ctx, param);

        assertEq(position.totalLeveragedQty, 50);
        assertEq(position.totalEntryAmount, 100000);
        assertEq(position._totalMakerMargin, 50);
        assertEq(position._totalTakerMargin, 90);
    }

    function _newLpContext() private view returns (LpContext memory) {
        return
            LpContext({
                oracleProvider: provider,
                interestCalculator: calculator,
                tokenPrecision: 10 * 18,
                _currentVersionCache: OracleVersion(0, 0, 0)
            });
    }

    function _newPositionParam() private pure returns (PositionParam memory) {
        return
            PositionParam({
                oracleVersion: 1,
                leveragedQty: 50,
                takerMargin: 10,
                makerMargin: 50,
                timestamp: 1,
                _settleVersionCache: OracleVersion(0, 0, 0)
            });
    }
}
