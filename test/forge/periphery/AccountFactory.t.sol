// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {AccountFactory} from "@chromatic/periphery/AccountFactory.sol";

contract AccountFactoryMock is Test, AccountFactory {
    constructor()
        public
        AccountFactory(address(this), address(0)) // router, marketFactory
    {}

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testCreateAccount() public {
        // checkTopit1~3, checkData
        vm.expectEmit(false, true, false, false);
        emit AccountCreated(address(0), alice);

        vm.prank(alice);
        this.createAccount();

        vm.prank(alice);
        emit log_named_address("Alice Account : ", this.getAccount());
    }

    function testGetAccount() public {
        this.getAccount(alice);

        vm.expectRevert(bytes("Only Router can call"));
        vm.prank(bob);
        this.getAccount(alice);

        vm.expectRevert(bytes("Only Router can call"));
        vm.prank(alice);
        this.getAccount(alice);
    }
}
