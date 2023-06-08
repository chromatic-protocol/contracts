// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IWETH9} from "@chromatic/core/interfaces/IWETH9.sol";
import {IKeeperFeePayer} from "@chromatic/core/interfaces/IKeeperFeePayer.sol";
import {IChromaticMarketFactory} from "@chromatic/core/interfaces/IChromaticMarketFactory.sol";
import {Errors} from "@chromatic/core/libraries/Errors.sol";

/**
 * @title KeeperFeePayer
 * @dev A contract that pays keeper fees using a Uniswap router.
 */
contract KeeperFeePayer is IKeeperFeePayer {
    IChromaticMarketFactory factory;
    ISwapRouter uniswapRouter;
    IWETH9 public WETH9;

    event SetRouter(address indexed);

    /**
     * @dev Modifier to restrict access to only the DAO.
     */
    modifier onlyDao() {
        require(msg.sender == factory.dao(), Errors.ONLY_DAO_CAN_ACCESS);
        _;
    }

    /**
     * @dev Modifier to restrict access to only the Vault.
     */
    modifier onlyVault() {
        require(msg.sender == factory.vault(), Errors.ONLY_VAULT_CAN_ACCESS);
        _;
    }

    /**
     * @dev Constructor function.
     * @param _factory The address of the ChromaticMarketFactory contract.
     * @param _uniswapRouter The address of the Uniswap router contract.
     * @param _weth The address of the WETH9 contract.
     */
    constructor(IChromaticMarketFactory _factory, ISwapRouter _uniswapRouter, IWETH9 _weth) {
        factory = _factory;
        uniswapRouter = _uniswapRouter;
        WETH9 = _weth;
    }

    /**
     * @dev Sets the Uniswap router address.
     * @param _uniswapRouter The address of the Uniswap router contract.
     * @notice Only the DAO can call this function.
     */
    function setRouter(ISwapRouter _uniswapRouter) public onlyDao {
        uniswapRouter = _uniswapRouter;
        emit SetRouter(address(uniswapRouter));
    }

    /**
     * @inheritdoc IKeeperFeePayer
     * @dev Only the DAO can call this function.
     */
    function approveToRouter(address token, bool approve) external onlyDao {
        IERC20(token).approve(address(uniswapRouter), approve ? type(uint256).max : 0);
    }

    /**
     * @inheritdoc IKeeperFeePayer
     * @dev Only the Vault can call this function.
     */
    function payKeeperFee(
        address tokenIn,
        uint256 amountOut,
        address keeperAddress
    ) external onlyVault returns (uint256 amountIn) {
        uint256 balance = IERC20(tokenIn).balanceOf(address(this));

        amountIn = swapExactOutput(tokenIn, address(this), amountOut, balance);

        // unwrap
        WETH9.withdraw(amountOut);

        // send eth to keeper
        (bool success, ) = keeperAddress.call{value: amountOut}("");
        require(success, Errors.ETH_TRANSFER_FAILED);
        uint256 remainedBalance = IERC20(tokenIn).balanceOf(address(this));
        require(remainedBalance + amountIn >= balance, Errors.INVALID_SWAP_VALUE);

        SafeERC20.safeTransfer(IERC20(tokenIn), msg.sender, remainedBalance);
    }

    /**
     * @dev Executes a Uniswap swap with exact output amount.
     * @param tokenIn The address of the input token.
     * @param recipient The address that will receive the output tokens.
     * @param amountOut The desired amount of output tokens.
     * @param amountInMaximum The maximum amount of input tokens allowed for the swap.
     * @return amountIn The actual amount of input tokens used for the swap.
     */
    function swapExactOutput(
        address tokenIn,
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum
    ) internal returns (uint256 amountIn) {
        ISwapRouter.ExactOutputSingleParams memory swapParam = ISwapRouter.ExactOutputSingleParams(
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

    /**
     * @dev Fallback function to receive ETH payments.
     */
    receive() external payable {}

    /**
     * @dev Fallback function to receive ETH payments.
     */
    fallback() external payable {}
}
