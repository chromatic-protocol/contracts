// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {CLBTokenLib} from "@chromatic/core/libraries/CLBTokenLib.sol";

/**
 * @dev The LpAction enum represents the types of LP actions that can be performed.
 */
enum LpAction {
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY
}

/**
 * @title LpReceipt
 * @notice The LpReceipt struct represents a receipt of an LP action performed.
 */
struct LpReceipt {
    /// @dev An identifier for the receipt
    uint256 id;
    /// @dev The oracle version associated with the action
    uint256 oracleVersion;
    /// @dev The amount involved in the action,
    ///      when the action is `ADD_LIQUIDITY`, this value represents the amount of settlement tokens
    ///      when the action is `REMOVE_LIQUIDITY`, this value represents the amount of CLB tokens
    uint256 amount;
    /// @dev The address of the recipient of the action
    address recipient;
    /// @dev An enumeration representing the type of LP action performed (ADD_LIQUIDITY or REMOVE_LIQUIDITY)
    LpAction action;
    /// @dev The trading fee rate associated with the LP action
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
