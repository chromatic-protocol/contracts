// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {MarketBase} from "@usum/core/base/market/MarketBase.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";

abstract contract MarketValue is MarketBase {
    function newLpContext() internal view returns (LpContext memory) {
        IOracleProvider.OracleVersion memory _currentVersionCache;
        return
            LpContext({
                oracleProvider: oracleProvider,
                vault: vault,
                lpToken: lpToken,
                market: this,
                tokenPrecision: 10 ** settlementToken.decimals(),
                _currentVersionCache: _currentVersionCache
            });
    }

    function calculateInterest(
        uint256 amount,
        uint256 from,
        uint256 to
    ) public view override returns (uint256) {
        return factory.calculateInterest(address(settlementToken), amount, from, to);
    }
}
