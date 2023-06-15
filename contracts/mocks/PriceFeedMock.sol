// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {AggregatorProxyInterface} from "@chromatic/oracle/interfaces/AggregatorProxyInterface.sol";

contract PriceFeedMock is AggregatorProxyInterface {
    uint256 private constant PHASE_OFFSET = 64;
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
        latestRoundId = getStartingRoundId(currentPhaseId) - 1;
    }

    function increasePhase(int256 _answer) external {
        currentPhaseId += 1;
        latestRoundId = getStartingRoundId(currentPhaseId);
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

    function getAnswer(uint256 roundId) external view override returns (int256) {}

    function getTimestamp(uint256 roundId) external view override returns (uint256) {}

    function decimals() external view override returns (uint8) {
        return 18;
    }

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

    function getStartingRoundId(uint16 phaseId) internal pure returns (uint80) {
        return uint80(uint256(phaseId) << PHASE_OFFSET) + 1;
    }

    function phaseAggregators(uint16 phaseId) external view override returns (address) {
        return address(this);
    }

    function phaseId() external view override returns (uint16) {}

    function proposedAggregator() external view override returns (address) {}

    function proposedGetRoundData(
        uint80 roundId
    )
        external
        view
        override
        returns (
            uint80 id,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {}

    function proposedLatestRoundData()
        external
        view
        override
        returns (
            uint80 id,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {}

    function aggregator() external view override returns (address) {
        return address(this);
    }
}
