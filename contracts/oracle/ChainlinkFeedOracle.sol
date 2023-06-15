// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./interfaces/IOracleProvider.sol";
import "./types/ChainlinkAggregator.sol";

/**
 * @title ChainlinkOracle
 * @notice Chainlink implementation of the IOracle interface.
 * @dev One instance per Chainlink price feed should be deployed. Multiple products may use the same
 *      ChainlinkOracle instance if their payoff functions are based on the same underlying oracle.
 *      This implementation only support non-negative prices.
 */
contract ChainlinkFeedOracle is IOracleProvider {
    error UnableToSyncError();

    /// @dev Chainlink feed aggregator address
    ChainlinkAggregator public immutable aggregator;

    /// @dev Decimal offset used to normalize chainlink price to 18 decimals
    int256 private immutable _decimalOffset;

    /// @dev Mapping of the starting data for each underlying phase
    Phase[] private _phases;

    /// @dev Last roundID seen when `sync` was called
    uint256 private lastSyncedRoundId;

    struct Phase {
        uint128 startingVersion;
        uint128 startingRoundId;
    }

    /**
     * @notice Initializes the contract state
     * @param aggregator_ Chainlink price feed aggregator
     */
    constructor(ChainlinkAggregator aggregator_) {
        aggregator = aggregator_;

        _decimalOffset = SafeCast.toInt256(10 ** aggregator.decimals());

        ChainlinkRound memory firstSeenRound = aggregator.getLatestRound();

        // Load the phases array with empty phase values. these phases will be invalid if requested
        while (firstSeenRound.phaseId() > _phases.length) {
            _phases.push(Phase(uint128(0), uint128(0)));
        }

        // first seen round starts as version 0 at current phase
        _phases.push(Phase(uint128(0), uint128(firstSeenRound.roundId)));
        lastSyncedRoundId = firstSeenRound.roundId;
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function sync() external returns (OracleVersion memory) {
        // Fetch latest round
        ChainlinkRound memory round = aggregator.getLatestRound();

        // Revert if the round id is 0
        if (uint64(round.roundId) == 0) revert InvalidOracleRound();

        // If there is more than 1 phase to update, revert
        if (round.phaseId() - _latestPhaseId() > 1) {
            revert UnableToSyncError();
        }

        // Update phase annotation when new phase detected
        while (round.phaseId() > _latestPhaseId()) {
            // Get the round count for the latest phase
            (uint256 phaseRoundCount, uint256 nextStartingRoundId) = aggregator
                .getPhaseSwitchoverData(
                    _phases[_latestPhaseId()].startingRoundId,
                    lastSyncedRoundId,
                    round
                );

            // The starting version for the next phase is startingVersionForLatestPhase + roundCount
            _phases.push(
                Phase(
                    uint128(phaseRoundCount) + _phases[_latestPhaseId()].startingVersion,
                    uint128(nextStartingRoundId)
                )
            );
        }

        lastSyncedRoundId = round.roundId;

        // Return packaged oracle version
        return _buildOracleVersion(round);
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function currentVersion() public view returns (OracleVersion memory oracleVersion) {
        return _buildOracleVersion(aggregator.getLatestRound());
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function atVersion(uint256 version) public view returns (OracleVersion memory oracleVersion) {
        return _buildOracleVersion(aggregator.getRound(_versionToRoundId(version)), version);
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function atVersions(
        uint256[] calldata versions
    ) external view returns (OracleVersion[] memory oracleVersions) {
        oracleVersions = new OracleVersion[](versions.length);
        for (uint i = 0; i < versions.length; i++) {
            oracleVersions[i] = atVersion(versions[i]);
        }
    }

    /**
     * @inheritdoc IOracleProvider
     */
    function description() external view override returns (string memory) {
        return AggregatorV2V3Interface(ChainlinkAggregator.unwrap(aggregator)).description();
    }

    /**
     * @notice Builds an oracle version object from a Chainlink round object
     * @dev Computes the version for the round
     * @param round Chainlink round to build from
     * @return Built oracle version
     */
    function _buildOracleVersion(
        ChainlinkRound memory round
    ) private view returns (OracleVersion memory) {
        Phase memory phase = _phases[round.phaseId()];
        uint256 version = uint256(phase.startingVersion) +
            round.roundId -
            uint256(phase.startingRoundId);
        return _buildOracleVersion(round, version);
    }

    /**
     * @notice Builds an oracle version object from a Chainlink round object
     * @param round Chainlink round to build from
     * @param version Determined version for the round
     * @return Built oracle version
     */
    function _buildOracleVersion(
        ChainlinkRound memory round,
        uint256 version
    ) private view returns (OracleVersion memory) {
        Fixed18 price = Fixed18Lib.ratio(round.answer, _decimalOffset);
        return OracleVersion({version: version, timestamp: round.timestamp, price: price});
    }

    /**
     * @notice Computes the chainlink round ID from a version
     * @param version Version to compute from
     * @return Chainlink round ID
     */
    function _versionToRoundId(uint256 version) private view returns (uint256) {
        Phase memory phase = _versionToPhase(version);
        return uint256(phase.startingRoundId) + version - uint256(phase.startingVersion);
    }

    /**
     * @notice Computes the chainlink phase ID from a version
     * @param version Version to compute from
     * @return phase Chainlink phase
     */
    function _versionToPhase(uint256 version) private view returns (Phase memory phase) {
        uint256 phaseId = _latestPhaseId();
        phase = _phases[phaseId];
        while (uint256(phase.startingVersion) > version) {
            phaseId--;
            phase = _phases[phaseId];
        }
    }

    /**
     * @notice Returns the latest phase ID that this contract has seen via `sync()`
     * @return Latest seen phase ID
     */
    function _latestPhaseId() private view returns (uint16) {
        return uint16(_phases.length - 1);
    }
}
