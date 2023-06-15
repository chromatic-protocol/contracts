// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IChromaticRouter} from "@chromatic/periphery/interfaces/IChromaticRouter.sol";
import {ChromaticAccount} from "@chromatic/periphery/ChromaticAccount.sol";

/**
 * @title AccountFactory
 * @dev Abstract contract for creating and managing user accounts.
 */
abstract contract AccountFactory is IChromaticRouter {
    ChromaticAccount private cloneBase;
    address private marketFactory;
    mapping(address => address) private accounts;

    /**
     * @dev Initializes the AccountFactory contract with the provided router and market factory addresses.
     * @param _marketFactory The address of the market factory contract.
     */
    constructor(address _marketFactory) {
        cloneBase = new ChromaticAccount();
        marketFactory = _marketFactory;
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function createAccount() external {
        address owner = msg.sender;
        require(accounts[owner] == address(0));

        ChromaticAccount newAccount = ChromaticAccount(Clones.clone(address(cloneBase)));
        newAccount.initialize(owner, address(this), marketFactory);
        accounts[owner] = address(newAccount);

        emit AccountCreated(address(newAccount), owner);
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function getAccount() external view returns (address) {
        return accounts[msg.sender];
    }

    /**
     * @notice Retrieves the address of a user's account.
     * @param accountAddress The address of the user's account.
     * @return The address of the user's account.
     */
    function getAccount(address accountAddress) internal view returns (address) {
        return accounts[accountAddress];
    }
}