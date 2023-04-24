// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {LpToken} from "@usum/core/base/market/LpToken.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {LpSlotKey, LpSlotKeyLib, Direction} from "@usum/core/libraries/LpSlotKey.sol";

contract OracleProviderMock is IOracleProvider {
    // add this to be excluded from coverage report
    function test() public {}

    function description() external pure override returns (string memory) {
        return "ETH / USD";
    }

    function syncVersion() external override returns (OracleVersion memory) {}

    function currentVersion()
        external
        view
        override
        returns (OracleVersion memory)
    {}

    function atVersion(
        uint256 oracleVersion
    ) external view override returns (OracleVersion memory) {}

    function pricePrecision() external view override returns (uint256) {}
}

contract LpTokenTest is Test, LpToken {
    OracleProviderMock public oracleProvider = new OracleProviderMock();

    function testUri() public {
        LpSlotKey id = LpSlotKeyLib.from(1000, Direction.Long);
        setImageUri("https://test.com/images/{id}.png");
        // setImageUri(
        //     "https:\\/\\/s3.amazonaws.com\\/your-bucket\\/images\\/{id}.png"
        // );
        emit log_string(uri(id.unwrap()));
    }
}
