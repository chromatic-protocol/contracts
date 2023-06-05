// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IOracleProvider} from "@chromatic/core/interfaces/IOracleProvider.sol";
import {AccruedInterest, AccruedInterestLib} from "@chromatic/core/external/liquidity/AccruedInterest.sol";
import {BinClosingPosition, BinClosingPositionLib} from "@chromatic/core/external/liquidity/BinClosingPosition.sol";
import {PositionParam} from "@chromatic/core/external/liquidity/PositionParam.sol";
import {PositionUtil} from "@chromatic/core/libraries/PositionUtil.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";

/**
 * @title BinClosedPosition
 * @notice Represents a closed position within an LiquidityBin.
 */
struct BinClosedPosition {
    uint256 _totalMakerMargin;
    BinClosingPosition _closing;
    EnumerableSet.UintSet _waitingVersions;
    mapping(uint256 => _ClaimWaitingPosition) _waitingPositions;
    AccruedInterest _accruedInterest;
}

/**
 * @title _ClaimWaitingPosition
 * @notice Represents the accumulated values of the waiting positions to be claimed
 *      for a specific version within BinClosedPosition.
 */
struct _ClaimWaitingPosition {
    int256 totalLeveragedQty;
    uint256 totalEntryAmount;
    uint256 totalMakerMargin;
    uint256 totalTakerMargin;
}

/**
 * @title BinClosedPositionLib
 * @notice A library that provides functions to manage the closed position within an LiquidityBin.
 */
library BinClosedPositionLib {
    using EnumerableSet for EnumerableSet.UintSet;
    using AccruedInterestLib for AccruedInterest;
    using BinClosingPositionLib for BinClosingPosition;

    /**
     * @notice Settles the closing position within the BinClosedPosition.
     * @dev If the closeVersion is not set or is equal to the current oracle version, no action is taken.
     *      Otherwise, the waiting position is stored and the accrued interest is accumulated.
     * @param self The BinClosedPosition storage.
     * @param ctx The LpContext memory.
     */
    function settleClosingPosition(
        BinClosedPosition storage self,
        LpContext memory ctx
    ) internal {
        uint256 closeVersion = self._closing.closeVersion;
        if (closeVersion == 0) return;

        IOracleProvider.OracleVersion memory currentVersion = ctx.currentOracleVersion();
        if (closeVersion >= currentVersion.version) return;

        _ClaimWaitingPosition memory waitingPosition = _ClaimWaitingPosition({
            totalLeveragedQty: self._closing.totalLeveragedQty,
            totalEntryAmount: self._closing.totalEntryAmount,
            totalMakerMargin: self._closing.totalMakerMargin,
            totalTakerMargin: self._closing.totalTakerMargin
        });

        // accumulate interest before update `_totalMakerMargin`
        self._accruedInterest.accumulate(ctx, self._totalMakerMargin, block.timestamp);

        self._totalMakerMargin += waitingPosition.totalMakerMargin;
        self._waitingVersions.add(closeVersion);
        self._waitingPositions[closeVersion] = waitingPosition;

        self._closing.settleAccruedInterest(ctx);
        self._accruedInterest.accumulatedAmount += self._closing.accruedInterest.accumulatedAmount;

        delete self._closing;
    }

    /**
     * @notice Closes the position within the BinClosedPosition.
     * @dev Delegates the onClosePosition function call to the underlying BinClosingPosition.
     * @param self The BinClosedPosition storage.
     * @param ctx The LpContext memory.
     * @param param The PositionParam memory.
     */
    function onClosePosition(
        BinClosedPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        self._closing.onClosePosition(ctx, param);
    }

    /**
     * @notice Claims the position within the BinClosedPosition.
     * @dev If the closeVersion is equal to the BinClosingPosition's closeVersion, the claim is made directly.
     *      Otherwise, the claim is made from the waiting position, and if exhausted, the waiting position is removed.
     *      The accrued interest is accumulated and deducted accordingly.
     * @param self The BinClosedPosition storage.
     * @param ctx The LpContext memory.
     * @param param The PositionParam memory.
     */
    function onClaimPosition(
        BinClosedPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        uint256 closeVersion = param.closeVersion;

        if (closeVersion == self._closing.closeVersion) {
            self._closing.onClaimPosition(ctx, param);
        } else {
            bool exhausted = _onClaimPosition(self._waitingPositions[closeVersion], ctx, param);

            // accumulate interest before update `_totalMakerMargin`
            self._accruedInterest.accumulate(ctx, self._totalMakerMargin, block.timestamp);

            self._totalMakerMargin -= param.makerMargin;
            self._accruedInterest.deduct(param.calculateInterest(ctx, block.timestamp));

            if (exhausted) {
                self._waitingVersions.remove(closeVersion);
                delete self._waitingPositions[closeVersion];
            }
        }
    }

    /**
     * @dev Claims the position from the waiting position within the BinClosedPosition.
     *      Updates the waiting position and returns whether the waiting position is exhausted.
     * @param waitingPosition The waiting position storage.
     * @param ctx The LpContext memory.
     * @param param The PositionParam memory.
     * @return exhausted Whether the waiting position is exhausted.
     */
    function _onClaimPosition(
        _ClaimWaitingPosition storage waitingPosition,
        LpContext memory ctx,
        PositionParam memory param
    ) private returns (bool exhausted) {
        int256 totalLeveragedQty = waitingPosition.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty;
        PositionUtil.checkRemovePositionQty(totalLeveragedQty, leveragedQty);
        if (totalLeveragedQty == leveragedQty) return true;

        waitingPosition.totalLeveragedQty = totalLeveragedQty - leveragedQty;
        waitingPosition.totalEntryAmount -= param.entryAmount(ctx);
        waitingPosition.totalMakerMargin -= param.makerMargin;
        waitingPosition.totalTakerMargin -= param.takerMargin;

        return false;
    }
}
