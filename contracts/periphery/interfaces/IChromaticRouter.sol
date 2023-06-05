// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticLiquidityCallback} from "@chromatic/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {Position} from "@chromatic/core/libraries/Position.sol";
import {LpReceipt} from "@chromatic/core/libraries/LpReceipt.sol";

interface IChromaticRouter is IChromaticLiquidityCallback {
    function openPosition(
        address market,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external returns (Position memory);

    function closePosition(address market, uint256 positionId) external;

    function claimPosition(address market, uint256 positionId) external;

    function addLiquidity(
        address market,
        int16 feeRate,
        uint256 amount,
        address recipient
    ) external returns (LpReceipt memory);

    function claimLiquidity(address market, uint256 receiptId) external;

    function removeLiquidity(
        address market,
        int16 feeRate,
        uint256 clbTokenAmount,
        address recipient
    ) external returns (LpReceipt memory);

    function withdrawLiquidity(address market, uint256 receiptId) external;

    function getAccount() external view returns (address);

    function getLpReceiptIds(address market) external view returns (uint256[] memory);

    function addLiquidityBatch(
        address market,
        int16[] calldata feeRates,
        uint256[] calldata amounts,
        address[] calldata recipients
    ) external returns (LpReceipt[] memory lpReceipts);

    function claimLiquidityBatch(address market, uint256[] calldata receiptIds) external;

    function removeLiquidityBatch(
        address market,
        int16[] calldata feeRates,
        uint256[] calldata clbTokenAmounts,
        address[] calldata recipients
    ) external returns (LpReceipt[] memory lpReceipts);

    function withdrawLiquidityBatch(address market, uint256[] calldata receiptIds) external;

    function calculateCLBTokenValueBatch(
        address market,
        int16[] calldata tradingFeeRates,
        uint256[] calldata clbTokenAmounts
    ) external view returns (uint256[] memory results);

    function calculateCLBTokenMintingBatch(
        address market,
        int16[] calldata tradingFeeRates,
        uint256[] calldata amounts
    ) external view returns (uint256[] memory results);

    function totalSupplies(
        address market,
        int16[] calldata tradingFeeRates
    ) external view returns (uint256[] memory supplies);
}
