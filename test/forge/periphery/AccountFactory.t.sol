// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {AccountFactory} from "@usum/periphery/AccountFactory.sol";
import {IAccountFactory} from "@usum/periphery/interfaces/IAccountFactory.sol";

contract AccountFactoryMock is Test {
    AccountFactory public accountFactory = new AccountFactory(address(this), address(0)); // router, marketFactory

    event AccountCreated(address);

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testCreateAccount() public {
        // checkTopit1~3, checkData
        vm.expectEmit(false, false, false, false);
        emit AccountCreated(address(0));

        vm.prank(alice);
        accountFactory.createAccount();

        vm.prank(alice);
        emit log_named_address("Alice Account : ", accountFactory.getAccount());
    }

    function testGetAccount() public {
        accountFactory.getAccount(alice);

        vm.expectRevert(bytes("Only Router can call"));
        vm.prank(bob);
        accountFactory.getAccount(alice);

        vm.expectRevert(bytes("Only Router can call"));
        vm.prank(alice);
        accountFactory.getAccount(alice);
    }
}
