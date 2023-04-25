// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Account} from "./Account.sol";
import {IAccount} from "./interfaces/IAccount.sol";
import {IAccountFactory} from "./interfaces/IAccountFactory.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract AccountFactory is IAccountFactory {
    Account private cloneBase;
    address private router;
    mapping(address => address) private accounts;

    constructor(address _router) {
        cloneBase = new Account();
        router = _router;
    }

    modifier onlyRouter() {
        require(msg.sender == router);
        _;
    }

    function createAccount() external {
        require(accounts[msg.sender] == address(0));
        Account newAccount = Account(Clones.clone(address(cloneBase)));
        newAccount.initialize(msg.sender, router);
        accounts[msg.sender] = address(newAccount);
    }

    function getAccount(
        address accountAddress
    ) external view onlyRouter returns (address) {
        return accounts[accountAddress];
    }
}
