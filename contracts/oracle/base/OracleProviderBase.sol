// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/IOracleProvider.sol";

abstract contract OracleProviderBase is IOracleProvider {
    int256 constant BASE = 1e18;

    function supportsInterface(bytes4 interfaceID) public pure virtual returns (bool) {
        return
            interfaceID == this.supportsInterface.selector ||
            type(IOracleProvider).interfaceId == interfaceID;
    }
}
