// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IUpkeepTreasury {
    function userBalance(address owner) external view returns (uint256);

    function useFunds(uint256 _amount, address _user) external;

    function depositFunds(address _receiver) external payable;

    function withdrawFunds(address payable _receiver, uint256 _amount) external;
}
