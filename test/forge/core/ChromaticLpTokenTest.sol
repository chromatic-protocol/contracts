// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {OracleProviderBase, IOracleProvider} from "@chromatic-protocol/contracts/oracle/base/OracleProviderBase.sol";
import {CLBToken} from "@chromatic-protocol/contracts/core/CLBToken.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";

contract OracleProviderMock is OracleProviderBase {
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

    function oracleProviderName() external pure override returns (string memory) {
        return "chainlink";
    }
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
            address(settlementToken),
            abi.encodeWithSelector(settlementToken.decimals.selector),
            abi.encode(6)
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
