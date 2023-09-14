// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IWETH9} from "@chromatic-protocol/contracts/core/interfaces/IWETH9.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";

/**
 * @title KeeperFeePayer
 * @dev A contract that pays keeper fees using a Uniswap router.
 */
contract KeeperFeePayer is IKeeperFeePayer {
    IChromaticMarketFactory immutable factory;
    ISwapRouter uniswapRouter;
    IWETH9 public immutable WETH9;

    /**
     * @dev Throws an error indicating that the caller is not the DAO.
     */
    error OnlyAccessableByDao();

    /**
     * @dev Throws an error indicating that the caller is nether the chormatic factory contract nor the DAO.
     */
    error OnlyAccessableByFactoryOrDao();

    /**
     * @dev Throws an error indicating that the transfer of keeper fee has failed.
     */
    error KeeperFeeTransferFailure();

    /**
     * @dev Throws an error indicating that the swap value for the Uniswap trade is invalid.
     */
    error InvalidSwapValue();

    /**
     * @dev Modifier to restrict access to only the DAO.
     *      Throws an `OnlyAccessableByDao` error if the caller is not the DAO.
     */
    modifier onlyDao() {
        if (msg.sender != factory.dao()) revert OnlyAccessableByDao();
        _;
    }

    /**
     * @dev Modifier to restrict access to only the factory or the DAO.
     *      Throws an `OnlyAccessableByFactoryOrDao` error if the caller is nether the chormatic factory contract nor the DAO.
     */
    modifier onlyFactoryOrDao() {
        if (msg.sender != address(factory) && msg.sender != factory.dao())
            revert OnlyAccessableByFactoryOrDao();
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
     * @dev Only the factory or the DAO can call this function.
     */
    function approveToRouter(address token, bool approve) external onlyFactoryOrDao {
        require(IERC20(token).approve(address(uniswapRouter), approve ? type(uint256).max : 0));
    }

    /**
     * @inheritdoc IKeeperFeePayer
     * @dev Throws a `KeeperFeeTransferFailure` error if the transfer of ETH to the keeper address fails.
     *      Throws an `InvalidSwapValue` error if the remaining balance of the input token after the swap is insufficient.
     */
    function payKeeperFee(
        address tokenIn,
        uint256 amountOut,
        address keeperAddress
    ) external returns (uint256 amountIn) {
        require(keeperAddress != address(0));
        uint256 balance = IERC20(tokenIn).balanceOf(address(this));

        amountIn = swapExactOutput(tokenIn, address(this), amountOut, balance);

        // unwrap
        WETH9.withdraw(amountOut);

        // send eth to keeper
        //slither-disable-next-line arbitrary-send-eth
        bool success = payable(keeperAddress).send(amountOut);
        if (!success) revert KeeperFeeTransferFailure();

        uint256 remainedBalance = IERC20(tokenIn).balanceOf(address(this));
        if (remainedBalance + amountIn < balance) revert InvalidSwapValue();

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
        if (tokenIn == address(WETH9)) return amountOut;

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
