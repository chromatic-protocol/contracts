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

        phases[chainlinkPriceFeeds[base][quote]].push(
            Phase({
                phaseId: LibChainlinkRound.getPhaseId(roundId),
                startingRoundId: roundId,
                startingVersion: 1
            })
        );
        chainlinkPriceFeeds[base][quote] = priceFeed;
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

        Phase[] storage syncedPhases = phases[chainlinkPriceFeeds[base][quote]];
        if (syncedPhases.length == 0) revert NotRegistered();

        // sync
        uint16 latestPhaseId = LibChainlinkRound.getPhaseId(roundId);
        uint256 latestSyncedPhaseIndex = syncedPhases.length - 1;
        Phase storage latestSyncedPhase = syncedPhases[latestSyncedPhaseIndex];
        if (latestSyncedPhase.phaseId < latestPhaseId) {
            uint256 latestPhaseRoundCnt = lastSyncedRoundId[priceFeed] -
                latestSyncedPhase.startingRoundId +
                1;

            syncedPhases.push(
                Phase({
                    phaseId: latestPhaseId,
                    startingRoundId: roundId,
                    startingVersion: latestSyncedPhase.startingVersion +
                        latestPhaseRoundCnt
                })
            );
        }
        // common
        lastSyncedRoundId[priceFeed] = roundId;
        uint256 version = latestSyncedPhase.startingVersion + roundId - latestSyncedPhase.startingRoundId;
        return OracleVersion({
            version: version,
            price:  answer,
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

            return uint80(phase.startingRoundId + (oracleVersion - phase.startingVersion));
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

        return OracleVersion({
            version: oracleVersion,
            price:  answer,
            timestamp: updatedAt
        });
    }
}
