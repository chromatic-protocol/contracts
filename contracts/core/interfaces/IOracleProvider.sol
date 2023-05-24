// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IOracleProvider as IPerennialOracleProvider} from "@equilibria/perennial-oracle/contracts/interfaces/IOracleProvider.sol";

interface IOracleProvider is IPerennialOracleProvider {
    function description() external view returns (string memory);

    function atVersions(
        uint256[] calldata versions
    ) external view returns (OracleVersion[] memory);
}
