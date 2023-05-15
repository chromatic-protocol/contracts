// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IAccountFactory {
    event AccountCreated(address account);

    function createAccount() external returns (address);

    function getAccount(address accountAddress) external view returns (address);

    function getAccount() external view returns (address);
}
