// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {ChromaticRouter} from "@chromatic-protocol/contracts/periphery/ChromaticRouter.sol";

contract ChromaticRouterMock is ChromaticRouter {
    using EnumerableSet for EnumerableSet.UintSet;

    constructor(address _marketFactory) ChromaticRouter(_marketFactory) {}

    function addLiquidity_directly(
        address market,
        int16 feeRate,
        uint256 amount,
        address recipient
    ) public returns (LpReceipt memory receipt) {
        receipt = IChromaticMarket(market).addLiquidity(
            recipient,
            feeRate,
            abi.encode(AddLiquidityCallbackData({provider: msg.sender, amount: amount}))
        );
        receiptIds[market][msg.sender].add(receipt.id);
    }

    function addLiquidityBatch_old(
        address market,
        address recipient,
        int16[] calldata feeRates,
        uint256[] calldata amounts
    ) external returns (LpReceipt[] memory lpReceipts) {
        require(feeRates.length == amounts.length, "TradeRouter: invalid arguments");
        lpReceipts = new LpReceipt[](feeRates.length);
        for (uint i; i < feeRates.length; ) {
            lpReceipts[i] = addLiquidity(market, feeRates[i], amounts[i], recipient);

            unchecked {
                i++;
            }
        }
    }

    function claimLiquidityBatch_old(address market, uint256[] calldata _receiptIds) external {
        for (uint i; i < _receiptIds.length; ) {
            claimLiquidity(market, _receiptIds[i]);

            unchecked {
                i++;
            }
        }
    }

    function removeLiquidityBatch_old(
        address market,
        address recipient,
        int16[] calldata feeRates,
        uint256[] calldata clbTokenAmounts
    ) external returns (LpReceipt[] memory lpReceipts) {
        require(feeRates.length == clbTokenAmounts.length, "TradeRouter: invalid arguments");
        lpReceipts = new LpReceipt[](feeRates.length);
        for (uint i; i < feeRates.length; ) {
            lpReceipts[i] = removeLiquidity(market, feeRates[i], clbTokenAmounts[i], recipient);

            unchecked {
                i++;
            }
        }
    }

    function withdrawLiquidityBatch_old(address market, uint256[] calldata _receiptIds) external {
        for (uint i; i < _receiptIds.length; ) {
            withdrawLiquidity(market, _receiptIds[i]);

            unchecked {
                i++;
            }
        }
    }
}
