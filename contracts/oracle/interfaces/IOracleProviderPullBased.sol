// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import {ExtraModule} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation1_1.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";

interface IOracleProviderPullBased is IOracleProvider {
    /**
     * @dev Returns the type of automation module that the Keeper will execute, either "None" or "Pyth".
     * @return Automation module type, which can be "None" or "Pyth".
     */
    function extraModule() external pure returns (ExtraModule);

    /**
     * @dev Retrieves the parameter needed to request data from the Keeper, e.g., the price feed ID in the case of Pyth integration.
     * @return Required parameter for Keeper requests as bytes
     */
    function extraParam() external view returns (bytes memory);

    /**
     * @dev Returns the fee required to update the Oracle Provider with the given off-chain data
     * @param offchainData Off-chain data required for the update
     * @return fee amount
     */
    function getUpdateFee(bytes calldata offchainData) external view returns (uint256);

    /**
     * @dev Updates the Oracle Provider with the provided off-chain data
     * @param offchainData Off-chain data used for the update
     */
    function updatePrice(bytes calldata offchainData) external payable;

    /**
     * @dev Parses the provided off-chain data received from the Keeper and returns an OracleVersion structure representing the parsed data
     * @param extraData Off-chain data received from the Keeper
     * @return Parsed OracleVersion structure
     */
    function parseExtraData(bytes calldata extraData) external view returns (OracleVersion memory);

    /**
     * @dev Retrieves the last synchronized oracle version
     * @return Last synchronized oracle version
     */
    function lastSyncedVersion() external view returns (OracleVersion memory);
}
