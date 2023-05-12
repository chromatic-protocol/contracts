// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IWETH9} from "@usum/core/interfaces/IWETH9.sol";
import {IKeeperFeePayer} from "@usum/core/interfaces/IKeeperFeePayer.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {Errors} from "@usum/core/libraries/Errors.sol";

contract KeeperFeePayer is IKeeperFeePayer {
    IUSUMMarketFactory factory;
    ISwapRouter uniswapRouter;
    IWETH9 public WETH9;

    event SetRouter(address);

    modifier onlyDao() {
        require(msg.sender == factory.dao(), Errors.ONLY_DAO_CAN_ACCESS);
        _;
    }

    constructor(
        IUSUMMarketFactory _factory,
        ISwapRouter _uniswapRouter,
        IWETH9 _weth
    ) {
        factory = _factory;
        uniswapRouter = _uniswapRouter;
        WETH9 = _weth;
    }

    function setRouter(ISwapRouter _uniswapRouter) public onlyDao {
        uniswapRouter = _uniswapRouter;
        emit SetRouter(address(uniswapRouter));
    }

    // this contrct doesn't have balance
    function approveToRouter(address token, bool approve) external onlyDao {
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
        require(success, Errors.ETH_TRANSFER_FAILED);
        uint256 remainedBalance = IERC20(tokenIn).balanceOf(address(this));
        require(
            remainedBalance + amountIn >= balance,
            Errors.INVALID_SWAP_VALUE
        );

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
                factory.getUniswapFeeTier(tokenIn),
                recipient,
                block.timestamp,
                amountOut,
                amountInMaximum,
                0
            );
        return uniswapRouter.exactOutputSingle(swapParam);
    }

    receive() external payable {}

    fallback() external payable {}
}
