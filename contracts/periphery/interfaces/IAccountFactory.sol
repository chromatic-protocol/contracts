// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IAccountFactory {
    function createAccount() external;

    function getAccount(address accountAddress) external view returns (address);

    function getAccount() external view returns (address);
}
