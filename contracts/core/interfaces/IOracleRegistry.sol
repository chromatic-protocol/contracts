// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";

interface IOracleRegistry {
    function register(
        address base,
        address quote,
        address chainlinkPriceFeed
    ) external;

    function getRegisteredProvider(
        address base,
        address quote
    ) external view returns (address);

    function isRegistered(
        address oracleProvider
    ) external view returns (bool);
}
