// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

interface AggregatorProxyInterface is AggregatorV2V3Interface {
    function phaseAggregators(uint16 _phaseId) external view returns (address);

    function phaseId() external view returns (uint16);

    function proposedAggregator() external view returns (address);

    function proposedGetRoundData(
        uint80 roundId
    )
        external
        view
        returns (
            uint80 id,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function proposedLatestRoundData()
        external
        view
        returns (
            uint80 id,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function aggregator() external view returns (address);
}
