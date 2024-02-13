// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IKeeperFeePayer
 * @dev Interface for a contract that pays keeper fees.
 */
interface IKeeperFeePayer {
    event SetRouter(address indexed);

    /**
     * @notice Approves or revokes approval to the Uniswap router for a given token.
     * @param token The address of the token.
     * @param approve A boolean indicating whether to approve or revoke approval.
     */
    function approveToRouter(address token, bool approve) external;

    /**
     * @notice Pays the keeper fee using Uniswap swaps.
     * @param tokenIn The address of the token being swapped.
     * @param amountOut The desired amount of output tokens.
     * @param keeperAddress The address of the keeper to receive the fee.
     * @return amountIn The actual amount of input tokens used for the swap.
     */
    function payKeeperFee(
        address tokenIn,
        uint256 amountOut,
        address keeperAddress
    ) external returns (uint256 amountIn);
}
