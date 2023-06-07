// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {CLBToken} from "@chromatic/core/CLBToken.sol";
import {IOracleProvider} from "@chromatic/core/interfaces/IOracleProvider.sol";
import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";

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

contract CLBTokenTest is Test, CLBToken {
    OracleProviderMock public oracleProvider = new OracleProviderMock();

    function setUp() public {
        IERC20Metadata settlementToken = IERC20Metadata(address(1));
        vm.mockCall(
            address(settlementToken),
            abi.encodeWithSelector(settlementToken.symbol.selector),
            abi.encode("USDC")
        );

        vm.mockCall(
            address(market),
            abi.encodeWithSelector(market.oracleProvider.selector),
            abi.encode(address(oracleProvider))
        );
        vm.mockCall(
            address(market),
            abi.encodeWithSelector(market.settlementToken.selector),
            abi.encode(address(settlementToken))
        );
    }

    function testUri() public {
        uint256 id = 1000;
        // setImageUri("https://test.com/images/{id}.png");
        // setImageUri(
        //     "https:\\/\\/s3.amazonaws.com\\/your-bucket\\/images\\/{id}.png"
        // );
        emit log_string(uri(id));
    }
}
