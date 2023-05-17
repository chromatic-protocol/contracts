// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import {ChainlinkRoundLib} from "../core/libraries/ChainlinkRoundLib.sol";

contract PriceFeedMock is AggregatorV2V3Interface {
    struct RoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    mapping(uint80 => RoundData) private roundDatas;
    uint80 latestRoundId;
    uint16 private currentPhaseId = 1;

    constructor() {
        latestRoundId =
            ChainlinkRoundLib.getStartingRoundId(currentPhaseId) -
            1;
    }

    function increasePhase(int256 _answer) external {
        currentPhaseId += 1;
        latestRoundId = ChainlinkRoundLib.getStartingRoundId(currentPhaseId);
        roundDatas[latestRoundId] = RoundData({
            roundId: latestRoundId,
            answer: _answer,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: latestRoundId
        });
    }

    function setRoundData(int256 _answer) external {
        latestRoundId += 1;
        roundDatas[latestRoundId] = RoundData({
            roundId: latestRoundId,
            answer: _answer,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: latestRoundId
        });
    }

    function latestAnswer() external view override returns (int256) {}

    function latestTimestamp() external view override returns (uint256) {}

    function latestRound() external view override returns (uint256) {}

    function getAnswer(
        uint256 roundId
    ) external view override returns (int256) {}

    function getTimestamp(
        uint256 roundId
    ) external view override returns (uint256) {}

    function decimals() external view override returns (uint8) {}

    function description() external view override returns (string memory) {}

    function version() external view override returns (uint256) {}

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        RoundData memory roundData = roundDatas[_roundId];
        return (
            roundData.roundId,
            roundData.answer,
            roundData.startedAt,
            roundData.updatedAt,
            roundData.answeredInRound
        );
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return this.getRoundData(latestRoundId);
    }
}
