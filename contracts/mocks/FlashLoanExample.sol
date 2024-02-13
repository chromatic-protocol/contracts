// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chromatic-protocol/contracts/core/interfaces/vault/ILendingPool.sol";
import "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticFlashLoanCallback.sol";

contract FlashLoanExample is IChromaticFlashLoanCallback {
    ILendingPool public lendingPool;

    struct FlashLoanCallbackData {
        address token;
        address recipient;
        uint256 amount;
    }

    constructor(address _lendingPoolAddress) {
        lendingPool = ILendingPool(_lendingPoolAddress);
    }

    function executeFlashLoan(address token, uint256 amount, address recipient) external {
        // Perform necessary operations before the flash loan

        // Create callback data
        bytes memory data = abi.encode(
            FlashLoanCallbackData({token: token, recipient: msg.sender, amount: amount})
        );

        // Execute the flash loan
        lendingPool.flashLoan(token, amount, recipient, data);

        // Perform necessary operations after the flash loan
    }

    function flashLoanCallback(uint256 fee, bytes calldata data) external override {
        // Handle the flash loan callback

        // Access and utilize the `data` parameter for additional processing
        FlashLoanCallbackData memory callbackData = abi.decode(data, (FlashLoanCallbackData));

        // Perform necessary operations after the flash loan has been executed
        SafeERC20.safeTransferFrom(
            IERC20(callbackData.token),
            callbackData.recipient,
            address(lendingPool),
            callbackData.amount + fee
        );
    }
}
