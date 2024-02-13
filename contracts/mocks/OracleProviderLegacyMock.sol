// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ChainlinkAggregator} from "@chromatic-protocol/contracts/oracle/types/ChainlinkAggregator.sol";

interface IOracleProviderLegacy {
    error InvalidOracleRound();

    struct OracleVersion {
        uint256 version;
        uint256 timestamp;
        int256 price;
    }

    function sync() external returns (OracleVersion memory);

    function currentVersion() external view returns (OracleVersion memory);

    function atVersion(uint256 version) external view returns (OracleVersion memory);

    function description() external view returns (string memory);

    function oracleProviderName() external view returns (string memory);
}

contract OracleProviderLegacyMock is IOracleProviderLegacy {
    ChainlinkAggregator public immutable aggregator;
    mapping(uint256 => OracleVersion) oracleVersions;
    uint256 private latestVersion;

    constructor() {
        aggregator = ChainlinkAggregator.wrap(address(0));
    }

    function increaseVersion(int256 price) public {
        latestVersion++;

        OracleVersion memory oracleVersion;
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
        if (oracleVersion.version == 0) {
            oracleVersion.version = version;
        }
    }

    function description() external pure override returns (string memory) {
        return "ETH / USD";
    }

    function atVersions(
        uint256[] calldata versions
    ) external view returns (OracleVersion[] memory results) {
        results = new OracleVersion[](versions.length);
        for (uint i; i < versions.length; ) {
            results[i] = atVersion(versions[i]);

            unchecked {
                ++i;
            }
        }
    }

    function oracleProviderName() external pure override returns (string memory) {
        return "chainlink";
    }
}
