// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IWETH9} from "@chromatic-protocol/contracts/core/interfaces/IWETH9.sol";

contract FixedPriceSwapRouter is ISwapRouter, Ownable {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal constant ZERO_ADDRESS = address(0);
    uint256 internal constant ETH_PRECISION = 1e18;

    IWETH9 public immutable WETH9;
    mapping(address token => uint256) public ethPriceInToken;
    EnumerableSet.AddressSet internal s_whitelistedClients;

    error DuplicateEntry();
    error NotContainedEntry();
    error EmptyAddress();
    error OnlyCallableByOwnerOrClient();
    error NotWETH();
    error NotRegisteredToken();
    error InvalidPrice();

    constructor(IWETH9 _weth) {
        WETH9 = _weth;
    }

    function setEthPriceInToken(address token, uint256 price) external onlyOwner {
        if (ZERO_ADDRESS == token) revert EmptyAddress();
        if (price == 0) revert InvalidPrice();
        ethPriceInToken[token] = price;
    }

    function withdraw(address token, uint256 amount) external onlyOwner {
        SafeERC20.safeTransfer(IERC20(token), msg.sender, amount);
    }

    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable override returns (uint256 amountIn) {
        if (msg.sender != owner() && !s_whitelistedClients.contains(msg.sender))
            revert OnlyCallableByOwnerOrClient();
        if (params.tokenOut != address(WETH9)) revert NotWETH();

        uint256 price = ethPriceInToken[params.tokenIn];
        if (price == 0) revert NotRegisteredToken();

        amountIn = params.amountOut.mulDiv(price, ETH_PRECISION);
        SafeERC20.safeTransferFrom(IERC20(params.tokenIn), msg.sender, address(this), amountIn);
        SafeERC20.safeTransfer(WETH9, params.recipient, params.amountOut);
    }

    function uniswapV3SwapCallback(int256, int256, bytes calldata) external pure override {
        revert("Not Implemented");
    }

    function exactInputSingle(
        ExactInputSingleParams calldata
    ) external payable override returns (uint256) {
        revert("Not Implemented");
    }

    function exactInput(ExactInputParams calldata) external payable override returns (uint256) {
        revert("Not Implemented");
    }

    function exactOutput(ExactOutputParams calldata) external payable override returns (uint256) {
        revert("Not Implemented");
    }

    function getWhitelistedClients() external view returns (address[] memory) {
        return s_whitelistedClients.values();
    }

    function addWhitelistedClient(address client) external onlyOwner {
        if (ZERO_ADDRESS == client) {
            revert EmptyAddress();
        }
        if (s_whitelistedClients.contains(client)) {
            revert DuplicateEntry();
        }
        s_whitelistedClients.add(client);
    }

    function removeWhitelistedClient(address client) external onlyOwner {
        if (!s_whitelistedClients.contains(client)) {
            revert NotContainedEntry();
        }
        s_whitelistedClients.remove(client);
    }

    fallback() external payable {
        if (msg.value > 0) {
            WETH9.deposit{value: msg.value}();
        }
    }
}
