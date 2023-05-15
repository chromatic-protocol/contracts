// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Account} from "./Account.sol";
import {IAccount} from "./interfaces/IAccount.sol";
import {IAccountFactory} from "./interfaces/IAccountFactory.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract AccountFactory is IAccountFactory {
    Account private cloneBase;
    address private router;
    address private marketFactory;
    mapping(address => address) private accounts;

    constructor(address _router, address _marketFactory) {
        cloneBase = new Account();
        router = _router;
        marketFactory = _marketFactory;
    }

    modifier onlyRouter() {
        require(msg.sender == router, "Only Router can call");
        _;
    }

    function createAccount(address owner) public returns (address) {
        require(accounts[owner] == address(0));
        Account newAccount = Account(Clones.clone(address(cloneBase)));
        newAccount.initialize(owner, router, marketFactory);
        accounts[owner] = address(newAccount);
        emit AccountCreated(address(newAccount));
        return address(newAccount);
    }

    function createAccount() external returns (address) {
        return createAccount(msg.sender);
    }

    function getAccount(
        address accountAddress
    ) external view onlyRouter returns (address) {
        return accounts[accountAddress];
    }

    function getAccount() external view returns (address) {
        return accounts[msg.sender];
    }
}
