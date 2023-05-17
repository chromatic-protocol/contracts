// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {PositionUtil, QTY_LEVERAGE_PRECISION} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotMargin} from "@usum/core/libraries/LpSlotMargin.sol";

/// @dev Position type
struct Position {
    /// @dev The position identifier
    uint256 id;
    /// @dev The version of the oracle when the position was created
    uint256 oracleVersion;
    /// @dev The quantity of the position
    int224 qty;
    /// @dev The leverage applied to the position
    uint32 leverage;
    /// @dev The timestamp when the position was created
    uint256 timestamp;
    /// @dev The amount of collateral that a trader must provide
    uint256 takerMargin;
    /// @dev The owner of the position, usually it is the account address of trader
    address owner;
    /// @dev The slot margins for the position, it represents the amount of collateral for each slot
    LpSlotMargin[] _slotMargins;
}

using PositionLib for Position global;

/**
 * @title PositionLib
 * @notice Provides functions that operate on the `Position` struct
 */
library PositionLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

    /**
     * @notice Returns the oracle version to settle based on the oracle version of the position
     * @param self The memory instance of `Position` struct
     * @return uint256 Next oracle version to settle
     */
    function settleVersion(
        Position memory self
    ) internal pure returns (uint256) {
        return PositionUtil.settleVersion(self.oracleVersion);
    }

    /**
     * @notice Calculates the leveraged quantity of the position
     *         based on the position's quantity and leverage
     * @param self The memory instance of `Position` struct
     * @param ctx The context object for this transaction
     * @return uint256 The leveraged quantity
     */
    function leveragedQty(
        Position memory self,
        LpContext memory ctx
    ) internal pure returns (int256) {
        int256 qty = self.qty;
        int256 leveraged = qty
            .abs()
            .mulDiv(self.leverage * ctx.tokenPrecision, QTY_LEVERAGE_PRECISION)
            .toInt256();
        return qty < 0 ? -leveraged : leveraged;
    }

    /**
     * @notice Calculates the entry price of the position based on the position's oracle version
     * @dev It fetches oracle price from `IOracleProvider`
     *      at the settle version calculated based on the position's oracle version 
     * @param self The memory instance of `Position` struct
     * @param provider The oracle provider
     * @return uint256 The entry price
     */
    function entryPrice(
        Position memory self,
        IOracleProvider provider
    ) internal view returns (uint256) {
        return PositionUtil.entryPrice(provider, self.oracleVersion);
    }

    /**
     * @notice Calculates the profit or loss of the position
     *         based on the current oracle version and the leveraged quantity
     * @param self The memory instance of `Position` struct
     * @param ctx The context object for this transaction
     * @return int256 The profit or loss
     */
    function pnl(
        Position memory self,
        LpContext memory ctx
    ) internal view returns (int256) {
        OracleVersion memory currentVersion = ctx.currentOracleVersion();
        return
            self.oracleVersion >= currentVersion.version
                ? int256(0)
                : PositionUtil.pnl(
                    self.leveragedQty(ctx),
                    uint256(ctx.oracleVersionAt(self.settleVersion()).price),
                    uint256(currentVersion.price)
                );
    }

    /**
     * @notice Calculates the total margin required for the makers of the position
     * @dev The maker margin is calculated by summing up the amounts of all slot margins
     *      in the `_slotMargins` array
     * @param self The memory instance of `Position` struct
     * @return margin The maker margin
     */
    function makerMargin(
        Position memory self
    ) internal pure returns (uint256 margin) {
        for (uint256 i = 0; i < self._slotMargins.length; i++) {
            margin += self._slotMargins[i].amount;
        }
    }

    /**
     * @notice Calculates the total trading fee for the position
     * @dev The trading fee is calculated by summing up the trading fees of all slot margins
     *      in the `_slotMargins` array
     * @param self The memory instance of `Position` struct
     * @return fee The trading fee
     */
    function tradingFee(
        Position memory self
    ) internal pure returns (uint256 fee) {
        for (uint256 i = 0; i < self._slotMargins.length; i++) {
            fee += self._slotMargins[i].tradingFee();
        }
    }

    /**
     * @notice Returns an array of LpSlotMargin instances
     *         representing the slot margins for the position
     * @param self The memory instance of `Position` struct
     * @return margins The slot margins for the position
     */
    function slotMargins(
        Position memory self
    ) internal pure returns (LpSlotMargin[] memory margins) {
        margins = self._slotMargins;
    }

    /**
     * @notice Sets the `_slotMargins` array for the position
     * @param self The memory instance of `Position` struct
     * @param margins The slot margins for the position
     */
    function setSlotMargins(
        Position memory self,
        LpSlotMargin[] memory margins
    ) internal pure {
        self._slotMargins = margins;
    }

    /**
     * @notice Stores the memory values of the `Position` struct to the storage
     * @param self The memory instance of `Position` struct
     * @param storedPosition The target storage
     */
    function storeTo(
        Position memory self,
        Position storage storedPosition
    ) internal {
        storedPosition.id = self.id;
        storedPosition.oracleVersion = self.oracleVersion;
        storedPosition.qty = self.qty;
        storedPosition.timestamp = self.timestamp;
        storedPosition.leverage = self.leverage;
        storedPosition.takerMargin = self.takerMargin;
        storedPosition.owner = self.owner;
        // can not convert memory array to storage array
        delete storedPosition._slotMargins;
        for (uint i = 0; i < self._slotMargins.length; i++) {
            LpSlotMargin memory slotMargin = self._slotMargins[i];
            if (slotMargin.amount > 0) {
                storedPosition._slotMargins.push(self._slotMargins[i]);
            }
        }
    }
}
