// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {MarketStorage, MarketStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";

abstract contract MarketFacetBase {
    /**
     * @dev Throws an error indicating that the caller is not the DAO.
     */
    error OnlyAccessableByDao();

    /**
     * @dev Throws an error indicating that the caller is not the chromatic liquidator contract.
     */

    error OnlyAccessableByLiquidator();

    /**
     * @dev Throws an error indicating that the caller is not the chromatch vault contract.
     */
    error OnlyAccessableByVault();

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
