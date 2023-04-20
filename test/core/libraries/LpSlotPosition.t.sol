// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {LpSlotPosition, LpSlotPositionLib} from "@usum/core/libraries/LpSlotPosition.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";

contract LpSlotPositionTest is Test {
    using LpSlotPositionLib for LpSlotPosition;

    IOracleProvider provider;
    LpSlotPosition position;

    function setUp() public {
        provider = IOracleProvider(address(1));
    }

    function testClosePosition() public {
        position.totalLeveragedQty = 100;
        position.totalEntryAmount = 200000;

        PositionParam memory param = _newPositionParam();
        param._settleVersionCache = OracleVersion({
            version: 2,
            timestamp: 2,
            price: 2000
        });
        param._currentVersionCache = OracleVersion({
            version: 3,
            timestamp: 3,
            price: 2100
        });

        position.closePosition(param, param.makerMargin);

        assertEq(position.totalLeveragedQty, 50);
        assertEq(position.totalEntryAmount, 100000);
    }

    function _newPositionParam() private view returns (PositionParam memory) {
        return
            PositionParam({
                oracleProvider: provider,
                interestCalculator: IInterestCalculator(address(0)),
                oracleVersion: 1,
                qty: 10,
                leverage: 5,
                takerMargin: 10,
                makerMargin: 50,
                timestamp: block.timestamp,
                _settleVersionCache: OracleVersion(0, 0, 0),
                _currentVersionCache: OracleVersion(0, 0, 0)
            });
    }
}
