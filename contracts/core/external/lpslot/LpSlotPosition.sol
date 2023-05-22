// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {UFixed18, UFixed18Lib} from "@equilibria/root/number/types/UFixed18.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {AccruedInterest, AccruedInterestLib} from "@usum/core/external/lpslot/AccruedInterest.sol";
import {LpSlotPendingPosition, LpSlotPendingPositionLib} from "@usum/core/external/lpslot/LpSlotPendingPosition.sol";
import {PositionParam} from "@usum/core/external/lpslot/PositionParam.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";

/// @dev LpSlotPosition type
struct LpSlotPosition {
    /// @dev The total leveraged quantity of the `LpSlot`
    int256 totalLeveragedQty;
    /// @dev The total entry amount of the `LpSlot`
    uint256 totalEntryAmount;
    /// @dev The total maker margin of the `LpSlot`
    uint256 _totalMakerMargin;
    /// @dev The total taker margin of the `LpSlot`
    uint256 _totalTakerMargin;
    /// @dev The pending position of the `LpSlot`
    LpSlotPendingPosition _pending;
    /// @dev The accumulated interest of the `LpSlot`
    AccruedInterest _accruedInterest;
}

/**
 * @title LpSlotPositionLib
 * @notice Library for managing positions in the `LpSlot`
 */
library LpSlotPositionLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;
    using AccruedInterestLib for AccruedInterest;
    using LpSlotPendingPositionLib for LpSlotPendingPosition;

    /**
     * @notice Settles accrued interest for a liquidity slot position.
     * @param self The LpSlotPosition storage struct.
     * @param ctx The LpContext data struct.
     */
    function settleAccruedInterest(
        LpSlotPosition storage self,
        LpContext memory ctx
    ) internal {
        self._accruedInterest.accumulate(
            ctx.market,
            self._totalMakerMargin,
            block.timestamp
        );
    }

    /**
     * @notice Settles pending positions for a liquidity slot position.
     * @param self The LpSlotPosition storage struct.
     * @param ctx The LpContext data struct.
     */
    function settlePendingPosition(
        LpSlotPosition storage self,
        LpContext memory ctx
    ) internal {
        uint256 pendingOracleVersion = self._pending.oracleVersion;
        if (pendingOracleVersion == 0) return;

        IOracleProvider.OracleVersion memory currentVersion = ctx
            .currentOracleVersion();
        if (pendingOracleVersion >= currentVersion.version) return;

        int256 pendingQty = self._pending.totalLeveragedQty;
        self.totalLeveragedQty += pendingQty;
        self.totalEntryAmount += pendingQty.abs().mulDiv(
            UFixed18.unwrap(self._pending.entryPrice(ctx)),
            UFixed18.unwrap(UFixed18Lib.ONE)
        );
        self._totalMakerMargin += self._pending.totalMakerMargin;
        self._totalTakerMargin += self._pending.totalTakerMargin;

        self._pending.settleAccruedInterest(ctx);
        self._accruedInterest.accumulatedAmount += self
            ._pending
            .accruedInterest
            .accumulatedAmount;

        delete self._pending;
    }

    /**
     * @notice Handles the opening of a position for a liquidity slot.
     * @param self The LpSlotPosition storage struct.
     * @param param The PositionParam data struct containing the position parameters.
     */
    function onOpenPosition(
        LpSlotPosition storage self,
        PositionParam memory param
    ) internal {
        self._pending.onOpenPosition(param);
    }

    /**
     * @notice Handles the closing of a position for a liquidity slot.
     * @param self The LpSlotPosition storage struct.
     * @param ctx The LpContext data struct.
     * @param param The PositionParam data struct containing the position parameters.
     */
    function onClosePosition(
        LpSlotPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        if (param.oracleVersion == self._pending.oracleVersion) {
            self._pending.onClosePosition(ctx, param);
        } else {
            int256 totalLeveragedQty = self.totalLeveragedQty;
            int256 leveragedQty = param.leveragedQty;
            PositionUtil.checkClosePositionQty(totalLeveragedQty, leveragedQty);

            self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
            self.totalEntryAmount -= leveragedQty.abs().mulDiv(
                UFixed18.unwrap(param.entryPrice(ctx)),
                UFixed18.unwrap(UFixed18Lib.ONE)
            );
            self._totalMakerMargin -= param.makerMargin;
            self._totalTakerMargin -= param.takerMargin;
            self._accruedInterest.deduct(
                param.calculateInterest(ctx, block.timestamp)
            );
        }
    }

    /**
     * @notice Returns the total maker margin for a liquidity slot position.
     * @param self The LpSlotPosition storage struct.
     * @return uint256 The total maker margin.
     */
    function totalMakerMargin(
        LpSlotPosition storage self
    ) internal view returns (uint256) {
        return self._totalMakerMargin + self._pending.totalMakerMargin;
    }

    /**
     * @notice Returns the total taker margin for a liquidity slot position.
     * @param self The LpSlotPosition storage struct.
     * @return uint256 The total taker margin.
     */
    function totalTakerMargin(
        LpSlotPosition storage self
    ) internal view returns (uint256) {
        return self._totalTakerMargin + self._pending.totalTakerMargin;
    }

    /**
     * @notice Calculates the unrealized profit or loss for a liquidity slot position.
     * @param self The LpSlotPosition storage struct.
     * @param ctx The LpContext data struct.
     * @return int256 The unrealized profit or loss.
     */
    function unrealizedPnl(
        LpSlotPosition storage self,
        LpContext memory ctx
    ) internal view returns (int256) {
        IOracleProvider.OracleVersion memory currentVersion = ctx
            .currentOracleVersion();

        int256 leveragedQty = self.totalLeveragedQty;
        int256 sign = leveragedQty < 0 ? int256(-1) : int256(1);
        UFixed18 exitPrice = PositionUtil.oraclePrice(currentVersion);

        int256 entryAmount = self.totalEntryAmount.toInt256() * sign;
        int256 exitAmount = leveragedQty
            .abs()
            .mulDiv(
                UFixed18.unwrap(exitPrice),
                UFixed18.unwrap(UFixed18Lib.ONE)
            )
            .toInt256() * sign;

        int256 rawPnl = exitAmount - entryAmount;
        int256 pnl = rawPnl +
            self._pending.unrealizedPnl(ctx) +
            _currentInterest(self, ctx).toInt256();
        uint256 absPnl = pnl.abs();

        if (pnl >= 0) {
            return Math.min(absPnl, self._totalTakerMargin).toInt256();
        } else {
            return -(Math.min(absPnl, self._totalMakerMargin).toInt256());
        }
    }

    /**
     * @dev Calculates the current interest for a liquidity slot position.
     * @param self The LpSlotPosition storage struct.
     * @param ctx The LpContext data struct.
     * @return uint256 The current interest.
     */
    function currentInterest(
        LpSlotPosition storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return _currentInterest(self, ctx) + self._pending.currentInterest(ctx);
    }

    /**
     * @dev Calculates the current interest for a liquidity slot position without pending position.
     * @param self The LpSlotPosition storage struct.
     * @param ctx The LpContext data struct.
     * @return uint256 The current interest.
     */
    function _currentInterest(
        LpSlotPosition storage self,
        LpContext memory ctx
    ) private view returns (uint256) {
        return
            self._accruedInterest.calculateInterest(
                ctx.market,
                self._totalMakerMargin,
                block.timestamp
            );
    }
}
