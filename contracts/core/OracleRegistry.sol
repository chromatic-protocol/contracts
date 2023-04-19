// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {LibChainlinkRound} from "./libraries/LibChainlinkRound.sol";
import {IOracleRegistry, OracleVersion} from "./interfaces/IOracleRegistry.sol";
import {IOracleProvider} from "./interfaces/IOracleProvider.sol";

import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract OracleRegistry is IOracleRegistry {
    mapping(address => mapping(address => IOracleProvider))
        private oracleProviders;

    mapping(address => bool) private registeredMap;

    event FeedRegistered(address base, address quote, address oracleProvider);

    error AlreadyRegistered();
    error NotRegistered();

    // TODO access control
    function register(
        address base,
        address quote,
        address oracleProvider
    ) external {
        if (address(oracleProviders[base][quote]) != address(0))
            revert AlreadyRegistered();

        oracleProviders[base][quote] = IOracleProvider(oracleProvider);
        registeredMap[oracleProvider] = true;

        emit FeedRegistered(base, quote, oracleProvider);
    }

    function getRegisteredProvider(
        address base,
        address quote
    ) external view returns (address) {
        return address(oracleProviders[base][quote]);
    }

    function isRegistered(
        address oracleProvider
    ) external view override returns (bool) {
        return registeredMap[oracleProvider];
    }
}
