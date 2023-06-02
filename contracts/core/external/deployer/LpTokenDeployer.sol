// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {USUMLpToken} from "@usum/core/USUMLpToken.sol";

/**
 * @title LpTokenDeployerLib
 * @notice Library for deploying LP tokens
 */
library LpTokenDeployerLib {
    /**
     * @notice Deploys a new LP token
     * @return lpToken The address of the deployed LP token
     */
    function deploy() external returns (address lpToken) {
        lpToken = address(new USUMLpToken());
    }
}
