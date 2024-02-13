// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/

import {IDiamondCut} from "@chromatic-protocol/contracts/core/interfaces/IDiamondCut.sol";
import {DiamondStorage, DiamondStorageLib} from "@chromatic-protocol/contracts/core/libraries/DiamondStorage.sol";

// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

abstract contract DiamondCutFacetBase is IDiamondCut {
    function _diamondCut(
        FacetCut[] calldata _cut,
        address _init,
        bytes calldata _calldata
    ) internal {
        DiamondStorage storage ds = DiamondStorageLib.diamondStorage();
        uint256 originalSelectorCount = ds.selectorCount;
        uint256 selectorCount = originalSelectorCount;
        bytes32 selectorSlot;
        // Check if last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8"
        if (selectorCount & 7 > 0) {
            // get last selectorSlot
            // "selectorCount >> 3" is a gas efficient division by 8 "selectorCount / 8"
            selectorSlot = ds.selectorSlots[selectorCount >> 3];
        }
        // loop through diamond cut
        for (uint256 facetIndex; facetIndex < _cut.length; ) {
            (selectorCount, selectorSlot) = DiamondStorageLib.addReplaceRemoveFacetSelectors(
                selectorCount,
                selectorSlot,
                _cut[facetIndex].facetAddress,
                _cut[facetIndex].action,
                _cut[facetIndex].functionSelectors
            );

            unchecked {
                facetIndex++;
            }
        }
        if (selectorCount != originalSelectorCount) {
            ds.selectorCount = uint16(selectorCount);
        }
        // If last selector slot is not full
        // "selectorCount & 7" is a gas efficient modulo by eight "selectorCount % 8"
        if (selectorCount & 7 > 0) {
            // "selectorCount >> 3" is a gas efficient division by 8 "selectorCount / 8"
            ds.selectorSlots[selectorCount >> 3] = selectorSlot;
        }
        emit DiamondCut(_cut, _init, _calldata);
        DiamondStorageLib.initializeDiamondCut(_init, _calldata);
    }
}
