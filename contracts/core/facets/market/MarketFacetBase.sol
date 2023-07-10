// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {MarketStorage, MarketStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";

abstract contract MarketFacetBase {
    error OnlyAccessableByDao();
    error OnlyAccessableByLiquidator();
    error OnlyAccessableByVault();

    /**
     * @dev Modifier to restrict access to only the DAO.
     */
    modifier onlyDao() {
        if (msg.sender != MarketStorageLib.marketStorage().factory.dao())
            revert OnlyAccessableByDao();
        _;
    }

    /**
     * @dev Modifier to restrict access to only the liquidator contract.
     */
    modifier onlyLiquidator() {
        if (msg.sender != address(MarketStorageLib.marketStorage().liquidator))
            revert OnlyAccessableByLiquidator();
        _;
    }

    /**
     * @dev Modifier to restrict a function to be called only by the vault contract.
     */
    modifier onlyVault() {
        if (msg.sender != address(MarketStorageLib.marketStorage().vault))
            revert OnlyAccessableByVault();
        _;
    }

    /**
     * @dev Creates a new LP context.
     * @return The LP context.
     */
    function newLpContext(MarketStorage storage ms) internal view returns (LpContext memory) {
        IOracleProvider.OracleVersion memory _currentVersionCache;
        return
            LpContext({
                oracleProvider: ms.oracleProvider,
                interestCalculator: ms.factory,
                vault: ms.vault,
                clbToken: ms.clbToken,
                market: address(this),
                settlementToken: address(ms.settlementToken),
                tokenPrecision: 10 ** ms.settlementToken.decimals(),
                _currentVersionCache: _currentVersionCache
            });
    }
}
