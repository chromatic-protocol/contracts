// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {USUMFactory} from "@usum/core/USUMFactory.sol";
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
    _SettlementTokenRegistry tokenRegistry;
    

    function setUp() public {
        tokenRegistry = new _SettlementTokenRegistry();
    }

    function testAccessControl() public{
        address attacker = vm.addr(1);
        vm.prank(attacker);

        vm.expectRevert(bytes("only DAO can access"));
        tokenRegistry.registerSettlementToken(address(12345));
        // tokenRegistry.updateDao(address(12345));
        // tokenRegistry.appendInterestRateRecord(address(12345),1,1);
        // tokenRegistry.removeLastInterestRateRecord(address(12345));
    }

    function testRegisterSettlementToken() public {
        // registerSettlementToken
        // isRegisteredSettlementToken
        // legnth
    }

    function testUpdateInterstRate() public {
        // appendInterestRateRecord
        // removeLastInterestRateRecord
        // currentInterestRate
    }

    function testCalculateInterest() public {
        // calculateInterest
    }
}







