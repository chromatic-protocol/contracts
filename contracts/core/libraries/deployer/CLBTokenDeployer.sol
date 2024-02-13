// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CLBToken} from "@chromatic-protocol/contracts/core/CLBToken.sol";

/**
 * @title CLBTokenDeployerLib
 * @notice Library for deploying CLB tokens
 */
library CLBTokenDeployerLib {
    /**
     * @notice Deploys a new CLB token
     * @return clbToken The address of the deployed CLB token
     */
    function deploy() external returns (address clbToken) {
        clbToken = address(new CLBToken());
    }
}
