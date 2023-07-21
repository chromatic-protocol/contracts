// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {UFixed18} from "@equilibria/root/number/types/UFixed18.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {AccruedInterest, AccruedInterestLib} from "@chromatic-protocol/contracts/core/libraries/liquidity/AccruedInterest.sol";
import {PositionParam} from "@chromatic-protocol/contracts/core/libraries/liquidity/PositionParam.sol";
import {PositionUtil} from "@chromatic-protocol/contracts/core/libraries/PositionUtil.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {Errors} from "@chromatic-protocol/contracts/core/libraries/Errors.sol";

/**
 * @dev Represents a pending position within the LiquidityBin
 * @param openVersion The oracle version when the position was opened.
 * @param totalLeveragedQty The total leveraged quantity of the pending position.
 * @param totalMakerMargin The total maker margin of the pending position.
 * @param totalTakerMargin The total taker margin of the pending position.
 * @param accruedInterest The accumulated interest of the pending position.
 */
struct BinPendingPosition {
    uint256 openVersion;
    int256 totalLeveragedQty;
    uint256 totalMakerMargin;
    uint256 totalTakerMargin;
    AccruedInterest accruedInterest;
}

/**
 * @title BinPendingPositionLib
 * @notice Library for managing pending positions in the `LiquidityBin`
 */
library BinPendingPositionLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;
    using AccruedInterestLib for AccruedInterest;

    /**
     * @notice Settles the accumulated interest of the pending position.
     * @param self The BinPendingPosition storage.
     * @param ctx The LpContext.
     */
    function settleAccruedInterest(BinPendingPosition storage self, LpContext memory ctx) internal {
        self.accruedInterest.accumulate(ctx, self.totalMakerMargin, block.timestamp);
    }

    /**
     * @notice Handles the opening of a position.
     * @dev Throws an error with the code `Errors.INVALID_ORACLE_VERSION` if the `openVersion` is not valid.
     * @param self The BinPendingPosition storage.
     * @param param The position parameters.
     */
    function onOpenPosition(
        BinPendingPosition storage self,
        LpContext memory ctx,
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

        // accumulate interest before update `totalMakerMargin`
        settleAccruedInterest(self, ctx);

        self.openVersion = param.openVersion;
        self.totalLeveragedQty = totalLeveragedQty + leveragedQty;
        self.totalMakerMargin += param.makerMargin;
        self.totalTakerMargin += param.takerMargin;
    }

    /**
     * @notice Handles the closing of a position.
     * @dev Throws an error with the code `Errors.INVALID_ORACLE_VERSION` if the `openVersion` is not valid.
     * @param self The BinPendingPosition storage.
     * @param ctx The LpContext.
     * @param param The position parameters.
     */
    function onClosePosition(
        BinPendingPosition storage self,
        LpContext memory ctx,
        PositionParam memory param
    ) internal {
        require(self.openVersion == param.openVersion, Errors.INVALID_ORACLE_VERSION);

        int256 totalLeveragedQty = self.totalLeveragedQty;
        int256 leveragedQty = param.leveragedQty;
        PositionUtil.checkRemovePositionQty(totalLeveragedQty, leveragedQty);

        // accumulate interest before update `totalMakerMargin`
        settleAccruedInterest(self, ctx);

        self.totalLeveragedQty = totalLeveragedQty - leveragedQty;
        self.totalMakerMargin -= param.makerMargin;
        self.totalTakerMargin -= param.takerMargin;
        self.accruedInterest.deduct(param.calculateInterest(ctx, block.timestamp));
    }

    /**
     * @notice Calculates the unrealized profit or loss (PnL) of the pending position.
     * @param self The BinPendingPosition storage.
     * @param ctx The LpContext.
     * @return uint256 The unrealized PnL.
     */
    function unrealizedPnl(
        BinPendingPosition storage self,
        LpContext memory ctx
    ) internal view returns (int256) {
        uint256 openVersion = self.openVersion;
        if (!ctx.isPastVersion(openVersion)) return 0;

        IOracleProvider.OracleVersion memory currentVersion = ctx.currentOracleVersion();
        UFixed18 _entryPrice = PositionUtil.settlePrice(
            ctx.oracleProvider,
            openVersion,
            ctx.currentOracleVersion()
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
     * @param self The BinPendingPosition storage.
     * @param ctx The LpContext.
     * @return uint256 The current accrued interest.
     */
    function currentInterest(
        BinPendingPosition storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return self.accruedInterest.calculateInterest(ctx, self.totalMakerMargin, block.timestamp);
    }

    /**
     * @notice Calculates the entry price of the pending position.
     * @param self The BinPendingPosition storage.
     * @param ctx The LpContext.
     * @return UFixed18 The entry price.
     */
    function entryPrice(
        BinPendingPosition storage self,
        LpContext memory ctx
    ) internal view returns (UFixed18) {
        return
            PositionUtil.settlePrice(
                ctx.oracleProvider,
                self.openVersion,
                ctx.currentOracleVersion()
            );
    }
}
