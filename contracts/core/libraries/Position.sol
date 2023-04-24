// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {PositionUtil, QTY_LEVERAGE_PRECISION} from "@usum/core/libraries/PositionUtil.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotMargin} from "@usum/core/libraries/LpSlotMargin.sol";

struct Position {
    uint256 oracleVersion;
    int224 qty;
    uint32 leverage;
    uint256 timestamp;
    uint256 takerMargin;
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
        return self._slotMargins;
    }

    function setSlotMargins(
        Position memory self,
        LpSlotMargin[] memory margins
    ) internal pure {
        self._slotMargins = margins;
    }
}
