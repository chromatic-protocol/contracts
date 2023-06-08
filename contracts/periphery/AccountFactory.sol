// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Account} from "./Account.sol";
import {IAccount} from "./interfaces/IAccount.sol";
import {IAccountFactory} from "./interfaces/IAccountFactory.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title AccountFactory
 * @dev Contract for creating and managing user accounts.
 */
contract AccountFactory is IAccountFactory {
    Account private cloneBase;
    address private router;
    address private marketFactory;
    mapping(address => address) private accounts;

    /**
     * @dev Initializes the AccountFactory contract with the provided router and market factory addresses.
     * @param _router The address of the router contract.
     * @param _marketFactory The address of the market factory contract.
     */
    constructor(address _router, address _marketFactory) {
        cloneBase = new Account();
        router = _router;
        marketFactory = _marketFactory;
    }

    /**
     * @dev Modifier to allow only the router contract to call a function.
     */
    modifier onlyRouter() {
        require(msg.sender == router, "Only Router can call");
        _;
    }

    /**
     * @inheritdoc IAccountFactory
     * @dev Only one account can be created per user.
     *      Emits an `AccountCreated` event upon successful creation.
     */
    function createAccount() external {
        address owner = msg.sender;
        require(accounts[owner] == address(0));

        Account newAccount = Account(Clones.clone(address(cloneBase)));
        newAccount.initialize(owner, router, marketFactory);
        accounts[owner] = address(newAccount);

        emit AccountCreated(address(newAccount), owner);
    }

    /**
     * @inheritdoc IAccountFactory
     */
    function getAccount(address accountAddress) external view onlyRouter returns (address) {
        return accounts[accountAddress];
    }

    /**
     * @inheritdoc IAccountFactory
     */
    function getAccount() external view returns (address) {
        return accounts[msg.sender];
    }
}
