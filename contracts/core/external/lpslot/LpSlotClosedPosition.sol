// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {AccruedInterest, AccruedInterestLib} from "@usum/core/external/lpslot/AccruedInterest.sol";
import {LpSlotClosingPosition, LpSlotClosingPositionLib} from "@usum/core/external/lpslot/LpSlotClosingPosition.sol";
import {PositionParam} from "@usum/core/external/lpslot/PositionParam.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";

/**
 * @title LpSlotClosedPosition
 * @notice Represents a closed position within an LpSlot.
 */
struct LpSlotClosedPosition {
    uint256 _totalMakerMargin;
    LpSlotClosingPosition _closing;
    EnumerableSet.UintSet _waitingVersions;
    mapping(uint256 => _ClaimWaitingPosition) _waitingPositions;
    AccruedInterest _accruedInterest;
}

/**
 * @title _ClaimWaitingPosition
 * @notice Represents the accumulated values of the waiting positions to be claimed
 *      for a specific version within LpSlotClosedPosition.
 */
struct _ClaimWaitingPosition {
    int256 totalLeveragedQty;
    uint256 totalEntryAmount;
    uint256 totalMakerMargin;
    uint256 totalTakerMargin;
}

/**
 * @title LpSlotClosedPositionLib
 * @notice A library that provides functions to manage the closed position within an LpSlot.
 */
library LpSlotClosedPositionLib {
    using EnumerableSet for EnumerableSet.UintSet;
    using AccruedInterestLib for AccruedInterest;
    using LpSlotClosingPositionLib for LpSlotClosingPosition;

    /**
     * @notice Settles the closing position within the LpSlotClosedPosition.
     * @dev If the closeVersion is not set or is equal to the current oracle version, no action is taken.
     *      Otherwise, the waiting position is stored and the accrued interest is accumulated.
     * @param self The LpSlotClosedPosition storage.
     * @param ctx The LpContext memory.
     */
    function settleClosingPosition(
        LpSlotClosedPosition storage self,
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
     * @notice Closes the position within the LpSlotClosedPosition.
     * @dev Delegates the onClosePosition function call to the underlying LpSlotClosingPosition.
     * @param self The LpSlotClosedPosition storage.
     * @param ctx The LpContext memory.
     * @param param The PositionParam memory.
     */
    function onClosePosition(
        LpSlotClosedPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        self._closing.onClosePosition(ctx, param);
    }

    /**
     * @notice Claims the position within the LpSlotClosedPosition.
     * @dev If the closeVersion is equal to the LpSlotClosingPosition's closeVersion, the claim is made directly.
     *      Otherwise, the claim is made from the waiting position, and if exhausted, the waiting position is removed.
     *      The accrued interest is accumulated and deducted accordingly.
     * @param self The LpSlotClosedPosition storage.
     * @param ctx The LpContext memory.
     * @param param The PositionParam memory.
     */
    function onClaimPosition(
        LpSlotClosedPosition storage self,
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
     * @dev Claims the position from the waiting position within the LpSlotClosedPosition.
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
