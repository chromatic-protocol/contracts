// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library ChainlinkRoundLib {
    /// @dev Phase ID offset location in the round ID
    uint256 constant PHASE_OFFSET = 64;

    function getPhaseId(uint80 roundId) internal pure returns (uint16) {
        return uint16(roundId >> PHASE_OFFSET);
    }
}
