// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import "./OracleProviderBase.sol";
import "../interfaces/IOracleProviderPullBased.sol";

abstract contract OracleProviderPullBasedBase is OracleProviderBase, IOracleProviderPullBased {
    function supportsInterface(
        bytes4 interfaceID
    ) public pure override(IERC165, OracleProviderBase) returns (bool) {
        return
            type(IOracleProviderPullBased).interfaceId == interfaceID ||
            super.supportsInterface(interfaceID);
    }

    /**
     * @dev Fallback function to receive ETH payments.
     */
    receive() external payable {}

    /**
     * @dev Fallback function to receive ETH payments.
     */
    fallback() external payable {}
}
