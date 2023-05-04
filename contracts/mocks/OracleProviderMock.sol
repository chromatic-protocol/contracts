// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";

contract OracleProviderMock is IOracleProvider {
    mapping(uint256 => OracleVersion) oracleVersions;
    uint256 private latestVersion;
    uint256 public immutable override pricePrecision = 10 ** 8; // 8 : ETH / USD decimals

    error InvalidVersion();

    function increaseVersion(int256 price) public {
        latestVersion++;
        oracleVersions[latestVersion] = OracleVersion({
            version:latestVersion,
            timestamp:block.timestamp,
            price:price
        });
    }

    function syncVersion() external override returns (OracleVersion memory) {
        return oracleVersions[latestVersion];
    }

    function currentVersion()
        external
        view
        override
        returns (OracleVersion memory)
    {
        return oracleVersions[latestVersion];
    }

    function atVersion(
        uint256 version
    ) external view override returns (OracleVersion memory oracleVersion) {
        oracleVersion = oracleVersions[version];
        if (version != oracleVersion.version) revert InvalidVersion();
    }

    function description() external pure override returns (string memory) {
        return "ETH / USD";
    }
}
