// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {LibChainlinkRound} from "./libraries/LibChainlinkRound.sol";
import {IOracleRegistry, OracleVersion, Phase} from "./interfaces/IOracleRegistry.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract OracleRegistry is IOracleRegistry {
    mapping(address => mapping(address => AggregatorV2V3Interface))
        private chainlinkPriceFeeds;
    mapping(AggregatorV2V3Interface => Phase[]) phases;
    mapping(AggregatorV2V3Interface => uint256) lastSyncedRoundId;

    event FeedRegistered(
        address base,
        address quote,
        address chainlinkPriceFeed
    );

    error AlreadyRegistered();
    error NotRegistered();
    error InvalidVersion();

    // TODO access control
    function register(
        address base,
        address quote,
        address chainlinkPriceFeed
    ) external {
        //
        require(address(chainlinkPriceFeeds[base][quote]) == address(0));
        AggregatorV2V3Interface priceFeed = AggregatorV2V3Interface(
            chainlinkPriceFeed
        );

        (uint80 roundId, , , , ) = priceFeed.latestRoundData();
        require(roundId > 0); // FIXME

        chainlinkPriceFeeds[base][quote] = priceFeed;
        lastSyncedRoundId[priceFeed] = roundId;
        phases[chainlinkPriceFeeds[base][quote]].push(
            Phase({
                phaseId: LibChainlinkRound.getPhaseId(roundId),
                startingRoundId: roundId,
                startingVersion: 1
            })
        );

        emit FeedRegistered(base, quote, chainlinkPriceFeed);
    }

    // with sync
    function syncVersion(
        address base,
        address quote
    ) external returns (OracleVersion memory) {
        AggregatorV2V3Interface priceFeed = chainlinkPriceFeeds[base][quote];
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,

        ) = priceFeed.latestRoundData();

        Phase[] storage syncedPhases = phases[priceFeed];
        if (syncedPhases.length == 0) revert NotRegistered();

        // sync
        uint16 currentPhaseId = LibChainlinkRound.getPhaseId(roundId);
        uint256 syncedPhaseIndex = syncedPhases.length - 1;
        Phase storage lastSyncedPhase = syncedPhases[syncedPhaseIndex];
        uint256 newVersion;
        if (lastSyncedPhase.phaseId < currentPhaseId) {
            newVersion =
                lastSyncedPhase.startingVersion +
                lastSyncedRoundId[priceFeed] -
                lastSyncedPhase.startingRoundId +
                1;

            syncedPhases.push(
                Phase({
                    phaseId: currentPhaseId,
                    startingRoundId: roundId,
                    startingVersion: newVersion
                })
            );
        } else {
            newVersion =
                lastSyncedPhase.startingVersion +
                roundId -
                lastSyncedPhase.startingRoundId;
        }
        lastSyncedRoundId[priceFeed] = roundId;
        return
            OracleVersion({
                version: newVersion,
                price: answer,
                timestamp: updatedAt
            });
    }

    function calcRoundId(
        Phase[] storage syncedPhases,
        uint256 oracleVersion
    ) internal view returns (uint80) {
        uint256 phaseIndex = syncedPhases.length - 1;
        while (phaseIndex >= 0) {
            Phase storage phase = syncedPhases[phaseIndex];
            if (oracleVersion < phase.startingVersion) {
                phaseIndex--;
                continue;
            }
            return
                uint80(
                    phase.startingRoundId +
                        (oracleVersion - phase.startingVersion)
                );
        }
        return 0;
    }

    function atVersion(
        address base,
        address quote,
        uint256 oracleVersion
    ) external view returns (OracleVersion memory) {
        Phase[] storage syncedPhases = phases[chainlinkPriceFeeds[base][quote]];
        uint256 latestSyncedRoundId = lastSyncedRoundId[
            chainlinkPriceFeeds[base][quote]
        ];

        // version
        uint80 roundId = calcRoundId(syncedPhases, oracleVersion);
        if (roundId > latestSyncedRoundId || roundId == 0)
            revert InvalidVersion();

        AggregatorV2V3Interface priceFeed = chainlinkPriceFeeds[base][quote];
        (
            uint256 _1,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,

        ) = priceFeed.getRoundData(roundId);

        return
            OracleVersion({
                version: oracleVersion,
                price: answer,
                timestamp: updatedAt
            });
    }
}
