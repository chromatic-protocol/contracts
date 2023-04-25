// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

struct OracleVersion {
    uint256 version;
    uint256 timestamp;
    int256 price;
}

struct Phase {
    uint16 phaseId;
    uint256 startingRoundId;
    uint256 startingVersion;
}

interface IOracleProvider {
    function description() external view returns (string memory);
    function syncVersion() external returns (OracleVersion memory);

    function currentVersion() external view returns (OracleVersion memory);

    function atVersion(
        uint256 oracleVersion
    ) external view returns (OracleVersion memory);

    function pricePrecision() external view returns (uint256);
}
