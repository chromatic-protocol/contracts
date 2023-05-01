// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IWETH9} from "@usum/core/interfaces/IWETH9.sol";
import {IKeeperFeePayer} from "@usum/core/interfaces/IKeeperFeePayer.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract KeeperFeePayer is IKeeperFeePayer, Ownable {
    ISwapRouter uniswapRouter;
    IWETH9 public WETH9;

    // TODO when liquidity is depleted???
    uint24 uniswapFee = 3000; // 0.3%
    // uint24 uniswapFee = 500; // 0.05%

    event SetRouter(address);
    event FeeChanged(uint24 previous, uint24 current);

    

    constructor(ISwapRouter _uniswapRouter, IWETH9 _weth) {
        uniswapRouter = _uniswapRouter;
        WETH9 = _weth;
    }

    function setRouter(ISwapRouter _uniswapRouter) public onlyOwner {
        uniswapRouter = _uniswapRouter;
        emit SetRouter(address(uniswapRouter));
    }

    function setUniswapFee(uint24 _fee) public onlyOwner {
        uint24 previousFee = uniswapFee;
        uniswapFee = _fee;
        emit FeeChanged(previousFee, uniswapFee);
    }

    // this contrct doesn't have balance
    function approveToRouter(address token, bool approve) external onlyOwner {
        IERC20(token).approve(
            address(uniswapRouter),
            approve ? type(uint256).max : 0
        );
    }

    function payKeeperFee(
        address tokenIn,
        uint256 amountOut,
        address keeperAddress
    ) external returns (uint256 amountIn) {
        uint256 balance = IERC20(tokenIn).balanceOf(address(this));

        amountIn = swapExactOutput(tokenIn, address(this), amountOut, balance);

        // unwrap
        WETH9.withdraw(amountOut);

        // send eth to keeper
        (bool success, ) = keeperAddress.call{value: amountOut}("");
        require(success, "_transfer: ETH transfer failed");
        uint256 remainedBalance = IERC20(tokenIn).balanceOf(address(this));
        require(remainedBalance + amountIn >= balance, "invaild swap value");

        SafeERC20.safeTransfer(tokenIn, msg.sender, remainedBalance);
    }

    // real swap execution
    function swapExactOutput(
        address tokenIn,
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum
    ) internal returns (uint256 amountIn) {
        ISwapRouter.ExactOutputSingleParams memory swapParam = ISwapRouter
            .ExactOutputSingleParams(
                tokenIn,
                address(WETH9),
                uniswapFee,
                recipient,
                block.timestamp,
                amountOut,
                amountInMaximum,
                0
            );
        return uniswapRouter.exactOutputSingle(swapParam);
    }


    receive() external payable{
    }
    fallback() external payable {
    }
}
