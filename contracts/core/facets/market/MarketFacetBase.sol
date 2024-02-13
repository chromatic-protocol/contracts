// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {MarketStorage, MarketStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {IMarketEvents} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketEvents.sol";
import {IMarketErrors} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketErrors.sol";

abstract contract MarketFacetBase is IMarketEvents, IMarketErrors {
    /**
     * @dev Modifier to restrict access to only the DAO.
     *      Throws an `OnlyAccessableByDao` error if the caller is not the DAO.
     */
    modifier onlyDao() {
        if (msg.sender != MarketStorageLib.marketStorage().factory.dao())
            revert OnlyAccessableByDao();
        _;
    }

    /**
     * @dev Modifier to restrict a function to be called only by the vault contract.
     *      Throws an `OnlyAccessableByVault` error if the caller is not the chromatic vault contract.
     */
    modifier onlyVault() {
        if (msg.sender != address(MarketStorageLib.marketStorage().vault))
            revert OnlyAccessableByVault();
        _;
    }

    modifier withTradingLock() {
        MarketStorageLib.marketStorage().vault.acquireTradingLock();
        _;
        MarketStorageLib.marketStorage().vault.releaseTradingLock();
    }

    /**
     * @dev Creates a new LP context.
     * @return The LP context.
     */
    function newLpContext(MarketStorage storage ms) internal view returns (LpContext memory) {
        //slither-disable-next-line uninitialized-local
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
