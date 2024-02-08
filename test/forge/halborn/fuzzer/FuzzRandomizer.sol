// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract FuzzRandomizer is Test {

    uint256 public currentRandomNumber;
    uint256 public calls;
    constructor (){
        while(currentRandomNumber == 0){
            currentRandomNumber = vm.envUint("FUZZ_ENTROPY");
        }
        calls = calls + 1;
    }

    function getRandomNumber() public returns (uint256){
        calls = calls + 1;
        if (currentRandomNumber == 0){
            currentRandomNumber = currentRandomNumber + 1;
        }
        unchecked{
            currentRandomNumber = currentRandomNumber * block.timestamp * 1e18 / calls;
        }
        return currentRandomNumber;
    }

    function getCurrentRandomNumber() public view returns (uint256){
        return currentRandomNumber;
    }

    function getRandomNumberWithEntropy(uint256 _n) public returns (uint256){
        calls = calls + 1;
        if (currentRandomNumber == 0){
            currentRandomNumber = currentRandomNumber + 1;
        }
        unchecked{
            currentRandomNumber = _n * currentRandomNumber * block.timestamp * 1e18 / calls;
        }
        return currentRandomNumber;
    }
}