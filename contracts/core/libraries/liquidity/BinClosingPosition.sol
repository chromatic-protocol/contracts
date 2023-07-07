// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {AccruedInterest, AccruedInterestLib} from "@chromatic-protocol/contracts/core/libraries/liquidity/AccruedInterest.sol";
import {PositionParam} from "@chromatic-protocol/contracts/core/libraries/liquidity/PositionParam.sol";
import {PositionUtil} from "@chromatic-protocol/contracts/core/libraries/PositionUtil.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {Errors} from "@chromatic-protocol/contracts/core/libraries/Errors.sol";

/**
 * @title BinClosingPosition
 * @dev Represents the closing position within an LiquidityBin.
 */
struct BinClosingPosition {
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
 * @title BinClosingPositionLib
 * @notice A library that provides functions to manage the closing position within an LiquidityBin.
 */
library BinClosingPositionLib {
    using AccruedInterestLib for AccruedInterest;

    /**
     * @notice Settles the accumulated interest of the closing position.
     * @param self The BinClosingPosition storage.
     * @param ctx The LpContext.
     */
    function settleAccruedInterest(BinClosingPosition storage self, LpContext memory ctx) internal {
        self.accruedInterest.accumulate(ctx, self.totalMakerMargin, block.timestamp);
    }

    /**
     * @notice Handles the closing of a position.
     * @param self The BinClosingPosition storage.
     * @param ctx The LpContext.
     * @param param The position parameters.
     */
    function onClosePosition(
        BinClosingPosition storage self,
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
     * @param self The BinPendingPosition storage.
     * @param ctx The LpContext.
     * @param param The position parameters.
     */
    function onClaimPosition(
        BinClosingPosition storage self,
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

    /**
     * @notice Calculates the current accrued interest of the closing position.
     * @param self The BinClosingPosition storage.
     * @param ctx The LpContext.
     * @return uint256 The current accrued interest.
     */
    function currentInterest(
        BinClosingPosition storage self,
        LpContext memory ctx
    ) internal view returns (uint256) {
        return self.accruedInterest.calculateInterest(ctx, self.totalMakerMargin, block.timestamp);
    }
}
