// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {UFixed18} from "@equilibria/root/number/types/UFixed18.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {AccruedInterest, AccruedInterestLib} from "@usum/core/external/lpslot/AccruedInterest.sol";
import {PositionParam} from "@usum/core/external/lpslot/PositionParam.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {Errors} from "@usum/core/libraries/Errors.sol";

/// @dev LpSlotPendingPosition type
struct LpSlotPendingPosition {
    /// @dev The oracle version when the position was opened.
    uint256 openVersion;
    /// @dev The total leveraged quantity of the pending position.
    int256 totalLeveragedQty;
    /// @dev The total maker margin of the pending position.
    uint256 totalMakerMargin;
    /// @dev The total taker margin of the pending position.
    uint256 totalTakerMargin;
    /// @dev The accumulated interest of the pending position.
    AccruedInterest accruedInterest;
}

/**
 * @title LpSlotPendingPositionLib
 * @notice Library for managing pending positions in the `LpSlot`
 */
library LpSlotPendingPositionLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;
    using AccruedInterestLib for AccruedInterest;

    /**
     * @notice Settles the accumulated interest of the pending position.
     * @param self The LpSlotPendingPosition storage.
     * @param ctx The LpContext.
     */
    function settleAccruedInterest(
        LpSlotPendingPosition storage self,
        LpContext memory ctx
    ) internal {
        self.accruedInterest.accumulate(ctx.market, self.totalMakerMargin, block.timestamp);
    }

    /**
     * @notice Handles the opening of a position.
     * @param self The LpSlotPendingPosition storage.
     * @param param The position parameters.
     */
    function onOpenPosition(
        LpSlotPendingPosition storage self,
        PositionParam memory param
    ) internal {
        uint256 openVersion = self.openVersion;
        require(
            openVersion == 0 || openVersion == param.openVersion,
            Errors.INVALID_ORACLE_VERSION
        );

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty;
        PositionUtil.checkAddPositionQty(totalLeveragedQty, leveragedQty);

        self.openVersion = param.openVersion;
        self.totalLeveragedQty = totalLeveragedQty + leveragedQty;
        self.totalMakerMargin += param.makerMargin;
        self.totalTakerMargin += param.takerMargin;
    }

    /**
     * @notice Handles the closing of a position.
     * @param self The LpSlotPendingPosition storage.
     * @param ctx The LpContext.
     * @param param The position parameters.
     */
    function onClosePosition(
        LpSlotPendingPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        require(self.openVersion == param.openVersion, Errors.INVALID_ORACLE_VERSION);

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty;
        PositionUtil.checkRemovePositionQty(totalLeveragedQty, leveragedQty);

        self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
        self.totalMakerMargin -= param.makerMargin;
        self.totalTakerMargin -= param.takerMargin;
        self.accruedInterest.deduct(param.calculateInterest(ctx, block.timestamp));
    }

    /**
     * @notice Calculates the unrealized profit or loss (PnL) of the pending position.
     * @param self The LpSlotPendingPosition storage.
     * @param ctx The LpContext.
     * @return uint256 The unrealized PnL.
     */
    function unrealizedPnl(
        LpSlotPendingPosition storage self,
        LpContext memory ctx
    ) internal view returns (int256) {
        if (self.openVersion == 0) return 0;

        IOracleProvider.OracleVersion memory currentVersion = ctx.currentOracleVersion();
        if (self.openVersion >= currentVersion.version) return 0;

        UFixed18 _entryPrice = PositionUtil.settlePrice(
            ctx.market.oracleProvider(),
            self.openVersion,
            currentVersion
        );
        UFixed18 _exitPrice = PositionUtil.oraclePrice(currentVersion);

        int256 pnl = PositionUtil.pnl(self.totalLeveragedQty, _entryPrice, _exitPrice) +
            currentInterest(self, ctx).toInt256();
        uint256 absPnl = pnl.abs();

        if (pnl >= 0) {
            return Math.min(absPnl, self.totalTakerMargin).toInt256();
        } else {
            return -(Math.min(absPnl, self.totalMakerMargin).toInt256());
        }
    }

    /**
     * @notice Calculates the current accrued interest of the pending position.
     * @param self The LpSlotPendingPosition storage.
     * @param ctx The LpContext.
     * @return uint256 The current accrued interest.
     */
    function currentInterest(
        LpSlotPendingPosition storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return
            self.accruedInterest.calculateInterest(
                ctx.market,
                self.totalMakerMargin,
                block.timestamp
            );
    }

    /**
     * @notice Calculates the entry price of the pending position.
     * @param self The LpSlotPendingPosition storage.
     * @param ctx The LpContext.
     * @return UFixed18 The entry price.
     */
    function entryPrice(
        LpSlotPendingPosition storage self,
        LpContext memory ctx
    ) internal view returns (UFixed18) {
        return
            PositionUtil.settlePrice(
                ctx.market.oracleProvider(),
                self.openVersion,
                ctx.currentOracleVersion()
            );
    }
}
