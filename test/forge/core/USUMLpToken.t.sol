// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {USUMLpToken} from "@usum/core/USUMLpToken.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";

contract OracleProviderMock is IOracleProvider {
    // add this to be excluded from coverage report
    function test() public {}

    function description() external pure override returns (string memory) {
        return "ETH / USD";
    }

    function sync() external override returns (IOracleProvider.OracleVersion memory) {}

    function currentVersion()
        external
        view
        override
        returns (IOracleProvider.OracleVersion memory)
    {}

    function atVersion(
        uint256 oracleVersion
    ) external view override returns (IOracleProvider.OracleVersion memory) {}

    function atVersions(
        uint256[] calldata versions
    ) external view override returns (OracleVersion[] memory) {}
}

contract USUMLpTokenTest is Test, USUMLpToken {
    OracleProviderMock public oracleProvider = new OracleProviderMock();

    function setUp() public {
        vm.mockCall(
            address(market),
            abi.encodeWithSelector(market.oracleProvider.selector),
            abi.encode(address(oracleProvider))
        );
    }

    function testUri() public {
        uint256 id = 1000;
        setImageUri("https://test.com/images/{id}.png");
        // setImageUri(
        //     "https:\\/\\/s3.amazonaws.com\\/your-bucket\\/images\\/{id}.png"
        // );
        emit log_string(uri(id));
    }
}
