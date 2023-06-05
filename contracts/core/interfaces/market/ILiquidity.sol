// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {LpReceipt} from "@chromatic/core/libraries/LpReceipt.sol";

interface ILiquidity {
    error TooSmallAmount();
    error OnlyAccessableByVault();
    error NotExistLpReceipt();
    error InvalidLpReceiptAction();

    event AddLiquidity(address indexed recipient, LpReceipt receipt);

    event ClaimLiquidity(
        address indexed recipient,
        uint256 indexed clbTokenAmount,
        LpReceipt receipt
    );

    event RemoveLiquidity(address indexed recipient, LpReceipt receipt);

    event WithdrawLiquidity(
        address indexed recipient,
        uint256 indexed amount,
        uint256 indexed burnedCLBTokenAmount,
        LpReceipt receipt
    );

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

    function withdrawLiquidity(uint256 receiptId, bytes calldata data) external;

    function getBinLiquidities(
        int16[] memory tradingFeeRate
    ) external returns (uint256[] memory amounts);

    function getBinFreeLiquidities(
        int16[] memory tradingFeeRate
    ) external returns (uint256[] memory amounts);

    function distributeEarningToBins(uint256 earning, uint256 marketBalance) external;

    function calculateCLBTokenMinting(
        int16 tradingFeeRate,
        uint256 amount
    ) external view returns (uint256);

    function calculateCLBTokenValue(
        int16 tradingFeeRate,
        uint256 clbTokenAmount
    ) external view returns (uint256);
}
