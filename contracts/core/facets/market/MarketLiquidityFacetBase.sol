// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {LpReceipt, LpAction} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {LpReceiptStorage, LpReceiptStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {FEE_RATES_LENGTH} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {MarketFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketFacetBase.sol";

abstract contract MarketLiquidityFacetBase is MarketFacetBase {
    function _getLpReceipt(
        LpReceiptStorage storage ls,
        uint256 receiptId
    ) internal view returns (LpReceipt memory receipt) {
        receipt = ls.getReceipt(receiptId);
        if (receipt.id == 0) revert NotExistLpReceipt();
    }

    /**
     * @dev Creates a new liquidity receipt.
     * @param ctx The liquidity context.
     * @param action The liquidity action.
     * @param amount The amount of liquidity.
     * @param recipient The address to receive the liquidity.
     * @param tradingFeeRate The trading fee rate for the liquidity.
     * @return The new liquidity receipt.
     */
    function _newLpReceipt(
        LpContext memory ctx,
        LpAction action,
        uint256 amount,
        address recipient,
        int16 tradingFeeRate
    ) internal returns (LpReceipt memory) {
        return
            LpReceipt({
                id: LpReceiptStorageLib.lpReceiptStorage().nextId(),
                oracleVersion: ctx.currentOracleVersion().version,
                action: action,
                amount: amount,
                recipient: recipient,
                tradingFeeRate: tradingFeeRate
            });
    }

    function _requireFeeRatesUniqueness(int16[] memory tradingFeeRates) internal pure {
        bool[FEE_RATES_LENGTH * 2] memory flags;

        for (uint256 i = 0; i < tradingFeeRates.length; ) {
            int16 feeRate = tradingFeeRates[i];
            uint256 idx = CLBTokenLib.feeRateIndex(uint16(feeRate < 0 ? -feeRate : feeRate));
            idx = feeRate < 0 ? idx + FEE_RATES_LENGTH : idx;

            if (flags[idx]) {
                revert DuplicatedTradingFeeRate();
            }
            flags[idx] = true;

            unchecked {
                ++i;
            }
        }
    }
}
