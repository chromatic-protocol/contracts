// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {PositionUtil, QTY_LEVERAGE_PRECISION} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/lpslot/LpContext.sol";
import {LpSlotMargin} from "@usum/core/lpslot/LpSlotMargin.sol";

struct Position {
    uint256 id;
    uint256 oracleVersion;
    int224 qty;
    uint32 leverage;
    uint256 timestamp;
    uint256 takerMargin;
    address owner;
    LpSlotMargin[] _slotMargins;
}

using PositionLib for Position global;

library PositionLib {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

    function settleVersion(
        Position memory self
    ) internal pure returns (uint256) {
        return PositionUtil.settleVersion(self.oracleVersion);
    }

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

    function entryPrice(
        Position memory self,
        IOracleProvider provider
    ) internal view returns (uint256) {
        return PositionUtil.entryPrice(provider, self.oracleVersion);
    }

    function pnl(
        Position memory self,
        LpContext memory ctx
    ) internal view returns (int256) {
        return
            PositionUtil.pnl(
                self.leveragedQty(ctx),
                uint256(ctx.oracleVersionAt(self.oracleVersion).price),
                uint256(ctx.currentOracleVersion().price)
            );
    }

    function makerMargin(
        Position memory self
    ) internal pure returns (uint256 margin) {
        for (uint256 i = 0; i < self._slotMargins.length; i++) {
            margin += self._slotMargins[i].amount;
        }
    }

    function tradingFee(
        Position memory self
    ) internal pure returns (uint256 fee) {
        for (uint256 i = 0; i < self._slotMargins.length; i++) {
            fee += self._slotMargins[i].tradingFee();
        }
    }

    function slotMargins(
        Position memory self
    ) internal pure returns (LpSlotMargin[] memory margins) {
        margins = self._slotMargins;
    }

    function setSlotMargins(
        Position memory self,
        LpSlotMargin[] memory margins
    ) internal pure {
        self._slotMargins = margins;
    }

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
            storedPosition._slotMargins.push(self._slotMargins[i]);
        }
    }
}
