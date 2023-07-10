// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {MarketStorage, MarketStorageLib, PositionStorage, PositionStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MarketFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketFacetBase.sol";

abstract contract MarketTradeFacetBase is MarketFacetBase {
    using SafeCast for uint256;
    using SignedMath for int256;

    error NotExistPosition();
    error ClaimPositionCallbackError();

    /**
     * @dev Internal function for claiming a position.
     * @param ctx The LpContext containing the current oracle version and synchronization information.
     * @param position The Position object representing the position to be claimed.
     * @param pnl The profit or loss amount of the position.
     * @param usedKeeperFee The amount of the keeper fee used.
     * @param recipient The address of the recipient (EOA or account contract) receiving the settlement.
     * @param data Additional data for the claim position callback.
     */
    function _claimPosition(
        LpContext memory ctx,
        Position memory position,
        int256 pnl,
        uint256 usedKeeperFee,
        address recipient,
        bytes memory data
    ) internal returns (uint256 interest) {
        uint256 makerMargin = position.makerMargin();
        uint256 takerMargin = position.takerMargin - usedKeeperFee;
        uint256 settlementAmount = takerMargin;

        // Calculate the interest based on the maker margin and the time difference
        // between the open timestamp and the current block timestamp
        interest = ctx.calculateInterest(makerMargin, position.openTimestamp, block.timestamp);

        // Calculate the realized profit or loss by subtracting the interest from the total pnl
        int256 realizedPnl = pnl - interest.toInt256();
        uint256 absRealizedPnl = realizedPnl.abs();
        if (realizedPnl > 0) {
            if (absRealizedPnl > makerMargin) {
                // If the absolute value of the realized pnl is greater than the maker margin,
                // set the realized pnl to the maker margin and add the maker margin to the settlement
                realizedPnl = makerMargin.toInt256();
                settlementAmount += makerMargin;
            } else {
                settlementAmount += absRealizedPnl;
            }
        } else {
            if (absRealizedPnl > takerMargin) {
                // If the absolute value of the realized pnl is greater than the taker margin,
                // set the realized pnl to the negative taker margin and set the settlement amount to 0
                realizedPnl = -(takerMargin.toInt256());
                settlementAmount = 0;
            } else {
                settlementAmount -= absRealizedPnl;
            }
        }

        MarketStorage storage ms = MarketStorageLib.marketStorage();

        // Accept the claim position in the liquidity pool
        ms.liquidityPool.acceptClaimPosition(ctx, position, realizedPnl);

        // Call the onClaimPosition function in the vault to handle the settlement
        ctx.vault.onClaimPosition(
            ctx.settlementToken,
            position.id,
            recipient,
            takerMargin,
            settlementAmount
        );

        // Call the claim position callback function on the position owner's contract
        // If an exception occurs during the callback, revert the transaction unless the caller is the liquidator
        try
            IChromaticTradeCallback(position.owner).claimPositionCallback(position.id, data)
        {} catch (bytes memory /* e */ /*lowLevelData*/) {
            if (msg.sender != address(ms.liquidator)) {
                revert ClaimPositionCallbackError();
            }
        }
        // Delete the claimed position from the positions mapping
        PositionStorageLib.positionStorage().deletePosition(position.id);
    }

    function _getPosition(
        PositionStorage storage ps,
        uint256 positionId
    ) internal view returns (Position memory position) {
        position = ps.getPosition(positionId);
        if (position.id == 0) revert NotExistPosition();
    }
}
