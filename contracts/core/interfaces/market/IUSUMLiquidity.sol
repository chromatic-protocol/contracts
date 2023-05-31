// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {LpReceipt} from "@usum/core/libraries/LpReceipt.sol";

interface IUSUMLiquidity {
    error TooSmallAmount();
    error OnlyAccessableByVault();
    error NotExistLpReceipt();
    error InvalidLpReceiptAction();

    event AddLiquidity(address indexed recipient, LpReceipt receipt);

    event ClaimLiquidity(
        address indexed recipient,
        uint256 indexed lpTokenAmount,
        LpReceipt receipt
    );

    event RemoveLiquidity(address indexed recipient, LpReceipt receipt);

    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (LpReceipt memory);

    function claimLiquidity(uint256 receiptId, bytes calldata data) external;

    function removeLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (LpReceipt memory);

    function getSlotLiquidities(
        int16[] memory tradingFeeRate
    ) external returns (uint256[] memory amounts);

    function getSlotFreeLiquidities(
        int16[] memory tradingFeeRate
    ) external returns (uint256[] memory amounts);

    function distributeEarningToSlots(uint256 earning, uint256 marketBalance) external;

    function calculateLpTokenMinting(
        int16 tradingFeeRate,
        uint256 amount
    ) external view returns (uint256);

    function calculateLpTokenValue(
        int16 tradingFeeRate,
        uint256 lpTokenAmount
    ) external view returns (uint256);
}
