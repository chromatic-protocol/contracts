// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {AccruedInterest, AccruedInterestLib} from "@chromatic/core/external/lpslot/AccruedInterest.sol";
import {PositionParam} from "@chromatic/core/external/lpslot/PositionParam.sol";
import {PositionUtil} from "@chromatic/core/libraries/PositionUtil.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {Errors} from "@chromatic/core/libraries/Errors.sol";

/**
 * @title LpSlotClosingPosition
 * @dev Represents the closing position within an LpSlot.
 */
struct LpSlotClosingPosition {
    /// @dev The oracle version when the position was closed.
    uint256 closeVersion;
    /// @dev The total leveraged quantity of the closing position.
    int256 totalLeveragedQty;
    /// @dev The total entry amount of the closing position.
    uint256 totalEntryAmount;
    /// @dev The total maker margin of the closing position.
    uint256 totalMakerMargin;
    /// @dev The total taker margin of the closing position.
    uint256 totalTakerMargin;
    /// @dev The accumulated interest of the closing position.
    AccruedInterest accruedInterest;
}

/**
 * @title LpSlotClosingPositionLib
 * @notice A library that provides functions to manage the closing position within an LpSlot.
 */
library LpSlotClosingPositionLib {
    using AccruedInterestLib for AccruedInterest;

    /**
     * @notice Settles the accumulated interest of the closing position.
     * @param self The LpSlotClosingPosition storage.
     * @param ctx The LpContext.
     */
    function settleAccruedInterest(
        LpSlotClosingPosition storage self,
        LpContext memory ctx
    ) internal {
        self.accruedInterest.accumulate(ctx, self.totalMakerMargin, block.timestamp);
    }

    /**
     * @notice Handles the closing of a position.
     * @param self The LpSlotClosingPosition storage.
     * @param ctx The LpContext.
     * @param param The position parameters.
     */
    function onClosePosition(
        LpSlotClosingPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        uint256 closeVersion = self.closeVersion;
        require(
            closeVersion == 0 || closeVersion == param.closeVersion,
            Errors.INVALID_ORACLE_VERSION
        );

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty;
        PositionUtil.checkAddPositionQty(totalLeveragedQty, leveragedQty);

        // accumulate interest before update `totalMakerMargin`
        settleAccruedInterest(self, ctx);

        self.closeVersion = param.closeVersion;
        self.totalLeveragedQty = totalLeveragedQty + leveragedQty;
        self.totalEntryAmount += param.entryAmount(ctx);
        self.totalMakerMargin += param.makerMargin;
        self.totalTakerMargin += param.takerMargin;
        self.accruedInterest.accumulatedAmount += param.calculateInterest(ctx, block.timestamp);
    }

    /**
     * @notice Handles the claiming of a position.
     * @param self The LpSlotPendingPosition storage.
     * @param ctx The LpContext.
     * @param param The position parameters.
     */
    function onClaimPosition(
        LpSlotClosingPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        require(self.closeVersion == param.closeVersion, Errors.INVALID_ORACLE_VERSION);

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty;
        PositionUtil.checkRemovePositionQty(totalLeveragedQty, leveragedQty);

        // accumulate interest before update `totalMakerMargin`
        settleAccruedInterest(self, ctx);

        self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
        self.totalEntryAmount -= param.entryAmount(ctx);
        self.totalMakerMargin -= param.makerMargin;
        self.totalTakerMargin -= param.takerMargin;
        self.accruedInterest.deduct(param.calculateInterest(ctx, block.timestamp));
    }
}
