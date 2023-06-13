// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ChromaticAccount} from "./ChromaticAccount.sol";
import {IChromaticAccount} from "./interfaces/IChromaticAccount.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title AccountFactory
 * @dev Contract for creating and managing user accounts.
 */
contract AccountFactory {
    ChromaticAccount private cloneBase;
    address private router;
    address private marketFactory;
    mapping(address => address) private accounts;

    /**
     * @dev Emitted when a new account is created.
     * @param account The address of the created account.
     * @param owner The address of the owner of the created account.
     */
    event AccountCreated(address indexed account, address indexed owner);

    /**
     * @dev Initializes the AccountFactory contract with the provided router and market factory addresses.
     * @param _router The address of the router contract.
     * @param _marketFactory The address of the market factory contract.
     */
    constructor(address _router, address _marketFactory) {
        cloneBase = new ChromaticAccount();
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
     * @notice Creates a new user account.
     * @dev Only one account can be created per user.
     *      Emits an `AccountCreated` event upon successful creation.
     */
    function createAccount() external {
        address owner = msg.sender;
        require(accounts[owner] == address(0));

        ChromaticAccount newAccount = ChromaticAccount(Clones.clone(address(cloneBase)));
        newAccount.initialize(owner, router, marketFactory);
        accounts[owner] = address(newAccount);

        emit AccountCreated(address(newAccount), owner);
    }

    /**
     * @notice Retrieves the address of a user's account.
     * @param accountAddress The address of the user's account.
     * @return The address of the user's account.
     */
    function getAccount(address accountAddress) external view onlyRouter returns (address) {
        return accounts[accountAddress];
    }

    /**
     * @notice Retrieves the address of the caller's account.
     * @return The address of the caller's account.
     */
    function getAccount() external view returns (address) {
        return accounts[msg.sender];
    }
}
