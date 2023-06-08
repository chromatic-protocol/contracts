// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IAccountFactory
 * @dev Interface for the AccountFactory contract, which creates and manages user accounts.
 */
interface IAccountFactory {
    /**
     * @dev Emitted when a new account is created.
     * @param account The address of the created account.
     * @param owner The address of the owner of the created account.
     */
    event AccountCreated(address indexed account, address indexed owner);

    /**
     * @notice Creates a new user account.
     */
    function createAccount() external;

    /**
     * @notice Retrieves the address of a user's account.
     * @param accountAddress The address of the user's account.
     * @return The address of the user's account.
     */
    function getAccount(address accountAddress) external view returns (address);

    /**
     * @notice Retrieves the address of the caller's account.
     * @return The address of the caller's account.
     */
    function getAccount() external view returns (address);
}
