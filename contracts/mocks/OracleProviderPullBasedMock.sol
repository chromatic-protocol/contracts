// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OracleProviderPullBasedBase, IOracleProvider, ExtraModule} from "@chromatic-protocol/contracts/oracle/base/OracleProviderPullBasedBase.sol";

contract OracleProviderPullBasedMock is OracleProviderPullBasedBase {
    mapping(uint256 => OracleVersion) oracleVersions;
    uint256 private latestVersion;

    constructor() {}

    function increaseVersion(int256 price) public {
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

    function extraModule() external pure override returns (ExtraModule) {
        return ExtraModule.Pyth;
    }

    function extraParam() external pure override returns (bytes memory) {
        return "0x";
    }

    function getUpdateFee(
        bytes calldata /* offchainData */
    ) external pure override returns (uint256) {
        return 1;
    }

    function updatePrice(bytes calldata offchainData) external payable override {}

    function parseExtraData(
        bytes calldata /* extraData */
    ) external view override returns (OracleVersion memory) {
        return oracleVersions[latestVersion];
    }

    function lastSyncedVersion() external view override returns (OracleVersion memory) {
        return oracleVersions[latestVersion];
    }
}
