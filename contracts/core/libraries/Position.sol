// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {LpSlotKey} from "@usum/core/libraries/LpSlotKey.sol";
import {LpSlotMargin} from "@usum/core/libraries/LpSlotMargin.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";

struct Position {
    uint256 oracleVersion;
    int256 qty;
    uint256 timestamp;
    uint256 leverage;
    uint256 takerMargin;
    LpSlotKey[] _slotKeys;
    mapping(LpSlotKey => uint256) _slotMargins;
}

using PositionLib for Position global;

library PositionLib {
    function settleVersion(
        Position storage self
    ) internal view returns (uint256) {
        return PositionUtil.settleVersion(self.oracleVersion);
    }

    function entryPrice(
        Position storage self,
        IOracleProvider provider
    ) internal view returns (uint256) {
        return PositionUtil.entryPrice(provider, self.oracleVersion);
    }

    function makerMargin(
        Position storage self
    ) internal view returns (uint256 margin) {
        LpSlotKey[] memory _keys = self._slotKeys;
        for (uint256 i = 0; i < _keys.length; i++) {
            margin += self._slotMargins[_keys[i]];
        }
    }

    function setSlotMargins(
        Position storage self,
        LpSlotMargin[] memory margins
    ) internal {
        delete self._slotKeys;

        for (uint256 i = 0; i < margins.length; i++) {
            LpSlotMargin memory margin = margins[i];
            self._slotKeys.push(margin.key);
            self._slotMargins[margin.key] = margin.amount;
        }
    }
}
