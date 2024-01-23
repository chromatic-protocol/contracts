// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import {ExtraModule} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation1_1.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";

interface IOracleProviderPullBased is IOracleProvider {
    function extraModule() external pure returns (ExtraModule);

    function extraParam() external view returns (bytes memory);

    function getUpdateFee(bytes calldata offchainData) external view returns (uint256);

    function updatePrice(bytes calldata offchainData) external payable;

    function parseExtraData(bytes calldata extraData) external view returns (OracleVersion memory);
}
