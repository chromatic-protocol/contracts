// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import {ChainlinkFeedOracle} from "@equilibria/perennial-oracle/contracts/ChainlinkFeedOracle.sol";
import {ChainlinkAggregator} from "@equilibria/perennial-oracle/contracts/types/ChainlinkAggregator.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";

contract OracleProvider is ChainlinkFeedOracle, IOracleProvider {
    constructor(address aggregator) ChainlinkFeedOracle(ChainlinkAggregator.wrap(aggregator)) {}

    function description() external view override returns (string memory) {
        return AggregatorV2V3Interface(ChainlinkAggregator.unwrap(aggregator)).description();
    }

    function atVersions(
        uint256[] calldata versions
    ) external view returns (OracleVersion[] memory oracleVersions) {
        oracleVersions = new OracleVersion[](versions.length);
        for (uint i = 0; i < versions.length; i++) {
            oracleVersions[i] = atVersion(versions[i]);
        }
    }
}
