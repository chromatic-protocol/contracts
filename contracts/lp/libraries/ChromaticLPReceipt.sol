// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @dev The ChromaticLPAction enum represents the types of LP actions that can be performed.
 */
enum ChromaticLPAction {
    ADD_LIQUIDITY,
    REMOVE_LIQUIDITY
}

/**
 * @dev The ChromaticLPReceipt struct represents a receipt of an LP action performed.
 * @param id An identifier for the receipt
 * @param oracleVersion The oracle version associated with the action
 * @param amount The amount involved in the action,
 *        when the action is `ADD_LIQUIDITY`, this value represents the amount of settlement tokens
 *        when the action is `REMOVE_LIQUIDITY`, this value represents the amount of CLB tokens
 * @param recipient The address of the recipient of the action
 * @param action An enumeration representing the type of LP action performed (ADD_LIQUIDITY or REMOVE_LIQUIDITY)
 */
struct ChromaticLPReceipt {
    uint256 id;
    uint256 oracleVersion;
    uint256 amount;
    address recipient;
    ChromaticLPAction action;
}
