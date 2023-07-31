// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {ChainlinkAggregator} from "@chromatic-protocol/contracts/oracle/types/ChainlinkAggregator.sol";
import {ChainlinkFeedOracle} from "@chromatic-protocol/contracts/oracle/ChainlinkFeedOracle.sol";
import {PriceFeedMock} from "contracts/mocks/PriceFeedMock.sol";

// forge test --fork-url https://eth.llamarpc.com --fork-block-number 10000000 -vv
contract OracleProviderTest is Test {
    event OracleVersionUpdated(uint256 newVersion, uint256 timestamp, int256 price);

    ChainlinkFeedOracle oracleProvider;
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
        IOracleProvider.OracleVersion memory ov = oracleProvider.sync();
        emit log_named_uint("version", ov.version);
        IOracleProvider.OracleVersion memory ovByVersion = oracleProvider.atVersion(ov.version);
        assertEq(ov.price, ovByVersion.price);
        (uint80 roundId, int256 feedPrice, , , ) = priceFeedMock.latestRoundData();
        assertEq(feedPrice, ovByVersion.price);
        emit log_named_uint("roundId", roundId);
        emit log_named_int("ov.price", ov.price);
        emit log_named_int("ovByVersion", ovByVersion.price);
        emit log_named_int("feedPrice", feedPrice);
        return ov.version;
    }

    function printOracleVersion() internal {
        IOracleProvider.OracleVersion memory ov = oracleProvider.sync();
        emit log_named_uint("version", ov.version);
        emit log_named_uint("timestamp", ov.version);
        emit log_named_int("price", ov.price);
    }

    function setUp() public {
        priceFeedMock = new PriceFeedMock();
        updateAnswer();
        oracleProvider = new ChainlinkFeedOracle(ChainlinkAggregator.wrap(address(priceFeedMock)));
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
