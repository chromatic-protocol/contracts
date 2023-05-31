// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {InterestRate} from "@usum/core/libraries/InterestRate.sol";
import {SettlementTokenRegistry, SettlementTokenRegistryLib} from "@usum/core/external/registry/SettlementTokenRegistry.sol";

contract SettlementTokenRegistryTest is Test {
    using SettlementTokenRegistryLib for SettlementTokenRegistry;

    uint256 private constant YEAR = 365 * 24 * 3600;
    address testToken = address(7777777);

    SettlementTokenRegistry tokenRegistry;

    function setUp() public {
        tokenRegistry.register(testToken, 0, 0, 0, 0, 0);
    }

    function testRegisterSettlementToken() public {
        address newToken = address(111);
        assertEq(tokenRegistry.isRegistered(testToken), true);

        // duplicated token address test
        vm.expectRevert(bytes("ART"));
        tokenRegistry.register(testToken, 0, 0, 0, 0, 0);

        assertEq(tokenRegistry.isRegistered(newToken), false);

        // register new token
        tokenRegistry.register(newToken, 0, 0, 0, 0, 0);
        assertEq(tokenRegistry.getInterestRateRecords(newToken).length, 1);
        assertEq(tokenRegistry.isRegistered(newToken), true);
        assertEq(tokenRegistry.currentInterestRate(newToken), 0);
    }

    function testInterestRate() public {
        // invalid timestamp test
        vm.expectRevert(bytes("IRPT"));
        appendInterestRate(1, 0);

        // expect interest not deleted
        tokenRegistry.removeLastInterestRateRecord(testToken);
        assertEq(tokenRegistry.getInterestRateRecords(testToken).length, 1);

        // append interest rate
        appendInterestRate(100, 1);

        // latestRateTime < newRateTime test
        vm.expectRevert(bytes("IRNA"));
        appendInterestRate(100, 1);

        assertEq(tokenRegistry.getInterestRateRecords(testToken).length, 2);
        assertEq(tokenRegistry.currentInterestRate(testToken), 0);
        vm.warp(block.timestamp + 1);
        assertEq(tokenRegistry.currentInterestRate(testToken), 100);

        vm.expectRevert(bytes("IRAA"));
        tokenRegistry.removeLastInterestRateRecord(testToken);

        // remove interest test
        appendInterestRate(200, 10);
        tokenRegistry.removeLastInterestRateRecord(testToken);
        assertEq(tokenRegistry.getInterestRateRecords(testToken).length, 2);
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

    function appendInterestRate(uint256 interestRate, uint256 increseTime) internal {
        tokenRegistry.appendInterestRateRecord(
            testToken,
            interestRate,
            block.timestamp + increseTime
        );
    }
}
