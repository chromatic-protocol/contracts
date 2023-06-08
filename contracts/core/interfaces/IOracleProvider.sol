// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IOracleProvider as IPerennialOracleProvider} from "@equilibria/perennial-oracle/contracts/interfaces/IOracleProvider.sol";

/**
 * @title IOracleProvider
 * @dev Interface for an Oracle Provider contract that extends the Perennial Oracle Provider interface.
 */
interface IOracleProvider is IPerennialOracleProvider {
    /**
     * @notice Retrieves the description of the Oracle Provider.
     * @return A string representing the description of the Oracle Provider.
     */
    function description() external view returns (string memory);

    /**
     * @notice Retrieves the Oracle Version instances at the specified versions.
     * @param versions An array of versions for which to retrieve the Oracle Versions.
     * @return oracleVersions An array of Oracle Version instances corresponding to the specified versions.
     */
    function atVersions(uint256[] calldata versions) external view returns (OracleVersion[] memory);
}
