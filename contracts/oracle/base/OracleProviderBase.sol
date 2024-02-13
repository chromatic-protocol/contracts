// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/IOracleProvider.sol";

abstract contract OracleProviderBase is IOracleProvider {
    function supportsInterface(bytes4 interfaceID) public pure virtual returns (bool) {
        return
            interfaceID == this.supportsInterface.selector ||
            type(IOracleProvider).interfaceId == interfaceID;
    }
}
