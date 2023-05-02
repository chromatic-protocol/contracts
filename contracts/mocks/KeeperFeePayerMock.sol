// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IKeeperFeePayer} from "@usum/core/interfaces/IKeeperFeePayer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract KeeperFeePayerMock is IKeeperFeePayer, Ownable {

    // this contrct doesn't have balance
    function approveToRouter(address token, bool approve) external onlyOwner {
        IERC20(token).approve(
            address(this),
            approve ? type(uint256).max : 0
        );
    }
    
    // 1:1 swap
    function payKeeperFee(
        address tokenIn,
        uint256 amountOut,
        address keeperAddress
    ) external returns (uint256 amountIn) {
        uint256 tokenBalance = IERC20(tokenIn).balanceOf(address(this));

        require(tokenBalance > amountOut, "balance of token is not enough");
        require(address(this).balance > amountOut, "balance of payer contract is not enough");


        // send eth to keeper
        (bool success, ) = keeperAddress.call{value: amountOut}("");
        require(success, "_transfer: ETH transfer failed");

        SafeERC20.safeTransfer(tokenIn, msg.sender, tokenBalance - amountOut);
    }

    receive() external payable{
    }
    fallback() external payable {
    }
}
