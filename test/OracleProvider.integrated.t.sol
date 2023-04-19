// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {OracleRegistry, OracleVersion} from "contracts/core/OracleRegistry.sol";
import {OracleProvider} from "contracts/core/OracleProvider.sol";
import {PriceFeedMock} from "contracts/mocks/PriceFeedMock.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

// forge test --fork-url https://eth.llamarpc.com --fork-block-number 10000000 -vv
contract OracleProviderTest is Test {
    OracleProvider oracleProvider;
    PriceFeedMock priceFeedMock;
    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address USD = 0x0000000000000000000000000000000000000348;
    int256 answer = 100000000;

    function updateAnswer() internal {
        priceFeedMock.setRoundData(answer);
        answer = (answer * 9) / 10;
    }

    function increasePhase() internal {
        priceFeedMock.increasePhase(answer);
        answer = (answer * 9) / 10;
    }

    function syncVersion() internal returns (uint256) {
        OracleVersion memory ov = oracleProvider.syncVersion();
        emit log_named_uint("version", ov.version);
        OracleVersion memory ovByVersion = oracleProvider.atVersion(ov.version);
        assertEq(ov.price, ovByVersion.price);
        (uint80 roundId, int256 feedPrice, , , ) = priceFeedMock
            .latestRoundData();
        assertEq(feedPrice, ovByVersion.price);
        emit log_named_uint("roundId", roundId);
        emit log_named_int("ov.price", ov.price);
        emit log_named_int("ovByVersion", ovByVersion.price);
        emit log_named_int("feedPrice", feedPrice);
        return ov.version;
    }

    function printOracleVersion() internal {
        OracleVersion memory ov = oracleProvider.syncVersion();
        emit log_named_uint("version", ov.version);
        emit log_named_uint("timestamp", ov.version);
        emit log_named_int("price", ov.price);
    }

    function setUp() public {
        priceFeedMock = new PriceFeedMock();
        updateAnswer();
        oracleProvider = new OracleProvider(address(priceFeedMock));
    }

    function testDiffPhase() public {
        syncVersion();
        updateAnswer();
        syncVersion();
        updateAnswer();
        syncVersion();
        updateAnswer();
        increasePhase();
        syncVersion();
        updateAnswer();
        syncVersion();
        updateAnswer();
    }
}
