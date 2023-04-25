// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
interface IAccountFactory {
    
    function createAccount() external;

    function getAccount(address accountAddress) external view returns (address);
}
