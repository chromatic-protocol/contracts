// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/// @dev Phase ID offset location in the round ID
uint256 constant PHASE_OFFSET = 64;

library ChainlinkRoundLib {
    function getPhaseId(uint80 roundId) internal pure returns (uint16) {
        return uint16(roundId >> PHASE_OFFSET);
    }

    function getStartingRoundId(uint16 phaseId) internal pure returns (uint80) {
        return uint80(uint256(phaseId) << PHASE_OFFSET) + 1;
    }

    function getAggregatorRoundId(uint80 roundId) internal pure returns (uint64) {
        return uint64(roundId);
    }
}
