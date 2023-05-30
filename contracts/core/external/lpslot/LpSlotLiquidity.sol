// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Errors} from "@usum/core/libraries/Errors.sol";

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
    using EnumerableSet for EnumerableSet.UintSet;

    function onAddLiquidity(
        LpSlotLiquidity storage self,
        uint256 amount,
        uint256 oracleVersion
    ) internal {
        uint256 pendingOracleVersion = self._pending.oracleVersion;
        require(
            pendingOracleVersion == 0 || pendingOracleVersion == oracleVersion,
            Errors.INVALID_ORACLE_VERSION
        );

        self._pending.tokenAmount += amount;
    }
}
