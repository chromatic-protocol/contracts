// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IWETH9} from "@chromatic-protocol/contracts/core/interfaces/IWETH9.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

struct SwapConfig {
    ISwapRouter uniswapRouter;
    uint24 uniswapFeeTier;
    IWETH9 WETH9;
}

abstract contract TokenSwappable {
    ISwapRouter uniswapRouter;
    uint24 uniswapFeeTier;
    IWETH9 WETH9;

    function _setSwapRouter(SwapConfig memory config) internal {
        uniswapRouter = config.uniswapRouter;
        uniswapFeeTier = config.uniswapFeeTier;
        WETH9 = config.WETH9;
    }

    function swapTokenFrom() internal virtual returns (address) {}

    function swapExactOutput(
        // address tokenIn,
        // address recipient,
        uint256 amountOut,
        uint256 amountInMaximum
    ) internal returns (uint256 amountIn) {
        if (swapTokenFrom() == address(WETH9)) return amountOut;

        ISwapRouter.ExactOutputSingleParams memory swapParam = ISwapRouter.ExactOutputSingleParams(
            swapTokenFrom(),
            address(WETH9),
            uniswapFeeTier,
            address(this),
            block.timestamp,
            amountOut,
            amountInMaximum,
            0
        );
        return uniswapRouter.exactOutputSingle(swapParam);
    }

    /**
     * @dev Fallback function to receive ETH payments.
     */
    receive() external payable {}

    /**
     * @dev Fallback function to receive ETH payments.
     */
    fallback() external payable {}
}
