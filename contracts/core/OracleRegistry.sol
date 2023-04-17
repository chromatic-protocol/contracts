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
    // mapping(address => mapping(address => uint256)) private startingVersion;
    // mapping(address => mapping(address => uint256)) private latestSyncedRoundId;

    event FeedRegistered(
        address base,
        address quote,
        address chainlinkPriceFeed
    );

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
                startingVersionId: 1
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
        require(syncedPhases.length > 0);

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
                    startingVersionId: latestSyncedPhase.startingVersionId +
                        latestPhaseRoundCnt
                })
            );
        }
        // common
        lastSyncedRoundId[priceFeed] = roundId;

        //TODO return 
    }

    // get version on current phase by using roundId
    function calcVersion(
        Phase memory phase,
        uint80 roundId
    ) internal returns (uint256) {
        uint256 currentVersion = roundId - phase.startingRoundId + 1;
        return currentVersion;
    }

    function atVersion(
        address base,
        address quote,
        uint256 oracleVersion  // 30 
    ) external view returns (OracleVersion memory) {
        // version prev 50
        // last- start = version update count  > 50 else < 50 search prev phase struct
        // loop
        Phase[] storage syncedPhases = phases[chainlinkPriceFeeds[base][quote]];
        uint256 phaseIndex = syncedPhases.length - 1;
        //TODO
        while (oracleVersion > 0) {
            // Phase storage phase = syncedPhases[phaseIndex];
            // phase.startingVersion
            // phaseIndex--;
        }
    }
}
