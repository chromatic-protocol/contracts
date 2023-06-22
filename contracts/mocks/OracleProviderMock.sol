// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Fixed18} from "@equilibria/root/number/types/Fixed18.sol";
import {ChainlinkAggregator} from "@chromatic-protocol/contracts/oracle/types/ChainlinkAggregator.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";

contract OracleProviderMock is IOracleProvider {
    ChainlinkAggregator public immutable aggregator;
    mapping(uint256 => OracleVersion) oracleVersions;
    uint256 private latestVersion;

    error InvalidVersion();

    constructor() {
        aggregator = ChainlinkAggregator.wrap(address(0));
    }

    function increaseVersion(Fixed18 price) public {
        latestVersion++;

        IOracleProvider.OracleVersion memory oracleVersion;
        oracleVersion.version = latestVersion;
        oracleVersion.timestamp = block.timestamp;
        oracleVersion.price = price;
        oracleVersions[latestVersion] = oracleVersion;
    }

    function sync() external view override returns (OracleVersion memory) {
        return oracleVersions[latestVersion];
    }

    function currentVersion() external view override returns (OracleVersion memory) {
        return oracleVersions[latestVersion];
    }

    function atVersion(
        uint256 version
    ) public view override returns (OracleVersion memory oracleVersion) {
        oracleVersion = oracleVersions[version];
        if (version != oracleVersion.version) revert InvalidVersion();
    }

    function description() external pure override returns (string memory) {
        return "ETH / USD";
    }

    function atVersions(
        uint256[] calldata versions
    ) external view returns (OracleVersion[] memory results) {
        results = new OracleVersion[](versions.length);
        for (uint i = 0; i < versions.length; i++) {
            results[i] = atVersion(versions[i]);
        }
    }
}
