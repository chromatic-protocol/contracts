// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {USUMLpToken} from "@usum/core/USUMLpToken.sol";

library LpTokenDeployerLib {
    function deploy() external returns (address lpToken) {
        lpToken = address(new USUMLpToken());
    }
}
