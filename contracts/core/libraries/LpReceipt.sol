// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";

/**
 * @dev The LpAction enum represents the types of LP actions that can be performed.
 */
enum LpAction {
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY
}

/**
 * @dev The LpReceipt struct represents a receipt of an LP action performed.
 * @param id An identifier for the receipt
 * @param oracleVersion The oracle version associated with the action
 * @param amount The amount involved in the action,
 *        when the action is `ADD_LIQUIDITY`, this value represents the amount of settlement tokens
 *        when the action is `REMOVE_LIQUIDITY`, this value represents the amount of CLB tokens
 * @param recipient The address of the recipient of the action
 * @param action An enumeration representing the type of LP action performed (ADD_LIQUIDITY or REMOVE_LIQUIDITY)
 * @param tradingFeeRate The trading fee rate associated with the LP action
 */
struct LpReceipt {
    uint256 id;
    uint256 oracleVersion;
    uint256 amount;
    address recipient;
    LpAction action;
    int16 tradingFeeRate;
}

using LpReceiptLib for LpReceipt global;

/**
 * @title LpReceiptLib
 * @notice Provides functions that operate on the `LpReceipt` struct
 */
library LpReceiptLib {
    /**
     * @notice Computes the ID of the CLBToken contract based on the trading fee rate.
     * @param self The LpReceipt struct.
     * @return The ID of the CLBToken contract.
     */
    function clbTokenId(LpReceipt memory self) internal pure returns (uint256) {
        return CLBTokenLib.encodeId(self.tradingFeeRate);
    }
}
