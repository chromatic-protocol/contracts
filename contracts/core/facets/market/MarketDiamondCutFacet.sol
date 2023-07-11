// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {DiamondCutFacetBase} from "@chromatic-protocol/contracts/core/facets/DiamondCutFacetBase.sol";
import {MarketStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";

contract MarketDiamondCutFacet is DiamondCutFacetBase {
    error OnlyAccessableByFactoryOrDao();

    /**
     * @dev Modifier to restrict access to only the factory or the DAO.
     */
    modifier onlyFactoryOrDao() {
        IChromaticMarketFactory factory = MarketStorageLib.marketStorage().factory;
        if (msg.sender != address(factory) && msg.sender != factory.dao())
            revert OnlyAccessableByFactoryOrDao();
        _;
    }

    /**
     * @notice Add/replace/remove any number of functions and optionally execute
     *         a function with delegatecall
     * @param _cut Contains the facet addresses and function selectors
     * @param _init The address of the contract or facet to execute _calldata
     * @param _calldata A function call, including function selector and arguments
     *                  _calldata is executed with delegatecall on _init
     */
    function diamondCut(
        FacetCut[] calldata _cut,
        address _init,
        bytes calldata _calldata
    ) external override onlyFactoryOrDao {
        _diamondCut(_cut, _init, _calldata);
    }
}