// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";

contract KeeperFeePayerMock is IKeeperFeePayer {
    IChromaticMarketFactory factory;

    modifier onlyFactoryOrDao() {
        require(
            msg.sender == address(factory) || msg.sender == factory.dao(),
            "only factory or DAO can access"
        );
        _;
    }


    constructor(IChromaticMarketFactory _factory) {
        factory = _factory;
    }

    // this contrct doesn't have balance
    function approveToRouter(address token, bool approve) external onlyFactoryOrDao {
        IERC20(token).approve(address(this), approve ? type(uint256).max : 0);
    }

    // 1:1 swap
    function payKeeperFee(
        address tokenIn,
        uint256 amountOut,
        address keeperAddress
    ) external returns (uint256 amountIn) {
        uint256 tokenBalance = IERC20(tokenIn).balanceOf(address(this));

        amountIn = amountOut;
        require(tokenBalance >= amountIn, "balance of token is not enough");
        require(address(this).balance >= amountOut, "balance of payer contract is not enough");

        // send eth to keeper
        (bool success, ) = keeperAddress.call{value: amountOut}("");
        require(success, "_transfer: ETH transfer failed");

        SafeERC20.safeTransfer(IERC20(tokenIn), msg.sender, tokenBalance - amountIn);
    }

    receive() external payable {}

    fallback() external payable {}
}
