// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";

struct Position {
    uint256 oracleVersion;
    int256 qty;
    uint256 timestamp;
    uint256 leverage;
    uint256 takerMargin;
    SlotMargin[] _slotMargins;
}

struct SlotMargin {
    uint16 tradingFeeRate;
    uint256 amount;
}

using PositionLib for Position global;

library PositionLib {
    function settleVersion(
        Position memory self
    ) internal pure returns (uint256) {
        return PositionUtil.settleVersion(self.oracleVersion);
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

    function setSlotMargins(
        Position memory self,
        SlotMargin[] memory margins
    ) internal pure {
        self._slotMargins = margins;
    }
}
