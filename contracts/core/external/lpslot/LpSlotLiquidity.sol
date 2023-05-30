// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Errors} from '@usum/core/libraries/Errors.sol';

struct LpSlotLiquidity {
    uint256 total;
    _PendingLiquidity _pending;
    EnumerableSet.UintSet _tokenWaitingVersions;
    EnumerableSet.UintSet _lpTokenWaitingVersions;
    mapping(uint256 => _PendingLiquidity) _tokenWaitingLiquidities;
    mapping(uint256 => _PendingLiquidity) _lpTokenWaitingLiquidities;
}

struct _PendingLiquidity {
    uint256 oracleVersion;
    uint256 tokenAmount;
    uint256 lpTokenAmount;
}

library LpSlotLiquidityLib {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev Minimum amount constant to prevent division by zero.
    uint256 private constant MIN_AMOUNT = 1000;

    function onAddLiquidity(LpSlotLiquidity storage self, uint256 amount, uint256 oracleVersion) internal {
        uint256 pendingOracleVersion = self._pending.oracleVersion;
        require(pendingOracleVersion == 0 || pendingOracleVersion == oracleVersion, Errors.INVALID_ORACLE_VERSION);

        self._pending.tokenAmount += amount;
    }

    function calculateLpTokenMinting(
        uint256 amount,
        uint256 slotValue,
        uint256 lpTokenTotalSupply
    ) internal pure returns (uint256) {
        return
            lpTokenTotalSupply == 0
                ? amount
                : amount.mulDiv(lpTokenTotalSupply, slotValue < MIN_AMOUNT ? MIN_AMOUNT : slotValue);
    }

    function calculateLpTokenValue(
        uint256 lpTokenAmount,
        uint256 slotValue,
        uint256 lpTokenTotalSupply
    ) internal pure returns (uint256) {
        return lpTokenAmount.mulDiv(slotValue, lpTokenTotalSupply);
    }
}
