// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";

struct Phase { 
    uint16 phaseId;
    uint256 startingRoundId;
    uint256 startingVersion;
}


// 1 1~100


// 2 30000000...000003 => 

// 1 -> 2
// 1 -> 2.stVersion

interface IOracleRegistry {
    function syncVersion(
        address base,
        address quote
    ) external returns (OracleVersion memory);

    function register(
        address base,
        address quote,
        address chainlinkPriceFeed
    ) external;

    function atVersion(
        address base,
        address quote,
        uint256 oracleVersion
    ) external view returns (OracleVersion memory);

    // function _sync()
}
