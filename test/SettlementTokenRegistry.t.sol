// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {USUMFactory} from "@usum/core/USUMFactory.sol";
import {SettlementTokenRegistry} from "@usum/core/base/SettlementTokenRegistry.sol";
import {Record} from "@usum/core/libraries/InterestRate.sol";

contract _SettlementTokenRegistry is USUMFactory {
    constructor() USUMFactory(address(0)) {}

    function _getInterestRateRecords(
        address token
    ) public view returns (Record[] memory) {
        return super.getInterestRateRecords(token);
    }
}

contract SettlementTokenRegistryTest is Test {
    uint256 private constant YEAR = 365 * 24 * 3600;
    _SettlementTokenRegistry tokenRegistry;
    address testToken = address(7777777);

    function setUp() public {
        tokenRegistry = new _SettlementTokenRegistry();
        tokenRegistry.registerSettlementToken(testToken);
    }

    function testAccessControl() public {
        // for InterestRateRecord append, remove testing
        appendInterestRate(100, 1);

        tokenRegistry.updateDao(address(1));

        vm.expectRevert(bytes("only DAO can access"));
        tokenRegistry.registerSettlementToken(address(12345));

        vm.expectRevert(bytes("only DAO can access"));
        tokenRegistry.updateDao(address(12345));

        vm.expectRevert(bytes("only DAO can access"));
        tokenRegistry.appendInterestRateRecord(address(12345), 1, 1);

        vm.expectRevert(bytes("only DAO can access"));
        tokenRegistry.removeLastInterestRateRecord(address(12345));
    }

    function testRegisterSettlementToken() public {
        address newToken = address(111);
        assertEq(tokenRegistry.isRegisteredSettlementToken(testToken), true);

        // duplicated token address test
        vm.expectRevert(
            SettlementTokenRegistry.AlreadyRegisteredToken.selector
        );
        tokenRegistry.registerSettlementToken(testToken);

        assertEq(tokenRegistry.isRegisteredSettlementToken(newToken), false);

        // register new token
        tokenRegistry.registerSettlementToken(newToken);
        assertEq(tokenRegistry._getInterestRateRecords(newToken).length, 1);
        assertEq(tokenRegistry.isRegisteredSettlementToken(newToken), true);
        assertEq(tokenRegistry.currentInterestRate(newToken), 0);
    }

    function testInterestRate() public {
        // invalid timestamp test
        vm.expectRevert(bytes("past timestamp"));
        appendInterestRate(1, 0);

        // expect interest not deleted
        tokenRegistry.removeLastInterestRateRecord(testToken);
        assertEq(tokenRegistry._getInterestRateRecords(testToken).length, 1);

        // append interest rate
        appendInterestRate(100, 1);

        // latestRateTime < newRateTime test
        vm.expectRevert(bytes("not appendable"));
        appendInterestRate(100, 1);

        assertEq(tokenRegistry._getInterestRateRecords(testToken).length, 2);
        assertEq(tokenRegistry.currentInterestRate(testToken), 0);
        vm.warp(block.timestamp + 1);
        assertEq(tokenRegistry.currentInterestRate(testToken), 100);

        // remove interest test
        tokenRegistry.removeLastInterestRateRecord(testToken);
        assertEq(tokenRegistry._getInterestRateRecords(testToken).length, 1);
    }

    function testCalculateInterest() public {
        
        // 0% interest
        assertEq(
            tokenRegistry.calculateInterest(
                testToken,
                1000,
                block.timestamp,
                block.timestamp + YEAR
            ),
            0
        );

        // 10% interest
        appendInterestRate(1000, YEAR / 2);

        // block.timestamp ~ (YEAR / 2)   :  0% interest => 0
        // block.timestamp + (YEAR / 2) ~ : 10% interest => 1000 * 0.05 = 50
        // total : 50
        assertEq(
            tokenRegistry.calculateInterest(
                testToken,
                1000,
                block.timestamp,
                block.timestamp + YEAR
            ),
            50
        );

        // block.timestamp + YEAR ~  :  10% interest => 1000 * 0.1 = 100
         assertEq(
            tokenRegistry.calculateInterest(
                testToken,
                1000,
                block.timestamp + YEAR,
                block.timestamp + YEAR * 2
            ),
            100
        );

    }


    function appendInterestRate(
        uint256 interestRate,
        uint256 increseTime
    ) internal {
        tokenRegistry.appendInterestRateRecord(
            testToken,
            interestRate,
            block.timestamp + increseTime
        );
    }
}
