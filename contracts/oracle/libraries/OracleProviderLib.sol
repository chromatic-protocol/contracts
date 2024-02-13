// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import {IOracleProvider} from "../interfaces/IOracleProvider.sol";
import {IOracleProviderPullBased} from "../interfaces/IOracleProviderPullBased.sol";

library OracleProviderLib {
    function isPullBased(IOracleProvider oracleProvider) internal view returns (bool) {
        try oracleProvider.supportsInterface(type(IOracleProviderPullBased).interfaceId) returns (
            bool supported
        ) {
            return supported;
        } catch (bytes memory /*lowLevelData*/) {
            // Contracts doesn't support ERC-165
            return false;
        }
    }
}
