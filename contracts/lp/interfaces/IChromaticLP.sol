// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ChromaticLPReceipt} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";

interface IChromaticLP {
    event AddLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 amount
    );

    event AddLiquiditySettled(uint256 indexed receiptId, uint256 lpTokenAmount);

    event RemoveLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 lpTokenAmount
    );

    event RemoveLiquiditySettled(uint256 indexed receiptId);

    event RebalanceLiquidity(uint256 indexed receiptId);
    event RebalanceSettled(uint256 indexed receiptId);

    function markets() external view returns (address[] memory);

    function settlementToken() external view returns (address);

    function lpToken() external view returns (address);

    function addLiquidity(
        uint256 amount,
        address recipient
    ) external returns (ChromaticLPReceipt memory);

    function removeLiquidity(
        uint256 lpTokenAmount,
        address recipient
    ) external returns (ChromaticLPReceipt memory);

    function getReceipts(address owner) external view returns (ChromaticLPReceipt[] memory);
}
