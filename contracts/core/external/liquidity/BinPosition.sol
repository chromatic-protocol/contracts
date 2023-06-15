// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {UFixed18} from "@equilibria/root/number/types/UFixed18.sol";
import {IOracleProvider} from "@chromatic/oracle/interfaces/IOracleProvider.sol";
import {PositionUtil} from "@chromatic/core/libraries/PositionUtil.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {AccruedInterest, AccruedInterestLib} from "@chromatic/core/external/liquidity/AccruedInterest.sol";
import {BinPendingPosition, BinPendingPositionLib} from "@chromatic/core/external/liquidity/BinPendingPosition.sol";
import {PositionParam} from "@chromatic/core/external/liquidity/PositionParam.sol";

/**
 * @title BinPosition
 * @notice Represents a position in the LiquidityBin
 */
struct BinPosition {
    /// @dev The total leveraged quantity of the `LiquidityBin`
    int256 totalLeveragedQty;
    /// @dev The total entry amount of the `LiquidityBin`
    uint256 totalEntryAmount;
    /// @dev The total maker margin of the `LiquidityBin`
    uint256 _totalMakerMargin;
    /// @dev The total taker margin of the `LiquidityBin`
    uint256 _totalTakerMargin;
    /// @dev The pending position of the `LiquidityBin`
    BinPendingPosition _pending;
    /// @dev The accumulated interest of the `LiquidityBin`
    AccruedInterest _accruedInterest;
}

/**
 * @title BinPositionLib
 * @notice Library for managing positions in the `LiquidityBin`
 */
library BinPositionLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;
    using AccruedInterestLib for AccruedInterest;
    using BinPendingPositionLib for BinPendingPosition;

    /**
     * @notice Settles pending positions for a liquidity bin position.
     * @param self The BinPosition storage struct.
     * @param ctx The LpContext data struct.
     */
    function settlePendingPosition(BinPosition storage self, LpContext memory ctx) internal {
        uint256 openVersion = self._pending.openVersion;
        if (openVersion == 0) return;

        IOracleProvider.OracleVersion memory currentVersion = ctx.currentOracleVersion();
        if (openVersion >= currentVersion.version) return;

        // accumulate interest before update `_totalMakerMargin`
        self._accruedInterest.accumulate(ctx, self._totalMakerMargin, block.timestamp);

        int256 pendingQty = self._pending.totalLeveragedQty;
        self.totalLeveragedQty += pendingQty;
        self.totalEntryAmount += PositionUtil.transactionAmount(
            pendingQty,
            self._pending.entryPrice(ctx)
        );
        self._totalMakerMargin += self._pending.totalMakerMargin;
        self._totalTakerMargin += self._pending.totalTakerMargin;

        self._pending.settleAccruedInterest(ctx);
        self._accruedInterest.accumulatedAmount += self._pending.accruedInterest.accumulatedAmount;

        delete self._pending;
    }

    /**
     * @notice Handles the opening of a position for a liquidity bin.
     * @param self The BinPosition storage.
     * @param ctx The LpContext data struct.
     * @param param The PositionParam containing the position parameters.
     */
    function onOpenPosition(
        BinPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        self._pending.onOpenPosition(ctx, param);
    }

    /**
     * @notice Handles the closing of a position for a liquidity bin.
     * @param self The BinPosition storage struct.
     * @param ctx The LpContext data struct.
     * @param param The PositionParam data struct containing the position parameters.
     */
    function onClosePosition(
        BinPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        if (param.openVersion == self._pending.openVersion) {
            self._pending.onClosePosition(ctx, param);
        } else {
            int256 totalLeveragedQty = self.totalLeveragedQty;
            int256 leveragedQty = param.leveragedQty;
            PositionUtil.checkRemovePositionQty(totalLeveragedQty, leveragedQty);

            // accumulate interest before update `_totalMakerMargin`
            self._accruedInterest.accumulate(ctx, self._totalMakerMargin, block.timestamp);

            self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
            self.totalEntryAmount -= param.entryAmount(ctx);
            self._totalMakerMargin -= param.makerMargin;
            self._totalTakerMargin -= param.takerMargin;
            self._accruedInterest.deduct(param.calculateInterest(ctx, block.timestamp));
        }
    }

    /**
     * @notice Returns the total maker margin for a liquidity bin position.
     * @param self The BinPosition storage struct.
     * @return uint256 The total maker margin.
     */
    function totalMakerMargin(BinPosition storage self) internal view returns (uint256) {
        return self._totalMakerMargin + self._pending.totalMakerMargin;
    }

    /**
     * @notice Returns the total taker margin for a liquidity bin position.
     * @param self The BinPosition storage struct.
     * @return uint256 The total taker margin.
     */
    function totalTakerMargin(BinPosition storage self) internal view returns (uint256) {
        return self._totalTakerMargin + self._pending.totalTakerMargin;
    }

    /**
     * @notice Calculates the unrealized profit or loss for a liquidity bin position.
     * @param self The BinPosition storage struct.
     * @param ctx The LpContext data struct.
     * @return int256 The unrealized profit or loss.
     */
    function unrealizedPnl(
        BinPosition storage self,
        LpContext memory ctx
    ) internal view returns (int256) {
        IOracleProvider.OracleVersion memory currentVersion = ctx.currentOracleVersion();

        int256 leveragedQty = self.totalLeveragedQty;
        int256 sign = leveragedQty < 0 ? int256(-1) : int256(1);
        UFixed18 exitPrice = PositionUtil.oraclePrice(currentVersion);

        int256 entryAmount = self.totalEntryAmount.toInt256() * sign;
        int256 exitAmount = PositionUtil.transactionAmount(leveragedQty, exitPrice).toInt256() *
            sign;

        int256 rawPnl = exitAmount - entryAmount;
        int256 pnl = rawPnl +
            self._pending.unrealizedPnl(ctx) +
            _currentInterest(self, ctx).toInt256();
        uint256 absPnl = pnl.abs();

        if (pnl >= 0) {
            return Math.min(absPnl, totalTakerMargin(self)).toInt256();
        } else {
            return -(Math.min(absPnl, totalMakerMargin(self)).toInt256());
        }
    }

    /**
     * @dev Calculates the current interest for a liquidity bin position.
     * @param self The BinPosition storage struct.
     * @param ctx The LpContext data struct.
     * @return uint256 The current interest.
     */
    function currentInterest(
        BinPosition storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return _currentInterest(self, ctx) + self._pending.currentInterest(ctx);
    }

    /**
     * @dev Calculates the current interest for a liquidity bin position without pending position.
     * @param self The BinPosition storage struct.
     * @param ctx The LpContext data struct.
     * @return uint256 The current interest.
     */
    function _currentInterest(
        BinPosition storage self,
        LpContext memory ctx
    ) private view returns (uint256) {
        return
            self._accruedInterest.calculateInterest(ctx, self._totalMakerMargin, block.timestamp);
    }
}
