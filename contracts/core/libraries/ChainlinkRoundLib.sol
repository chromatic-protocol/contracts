// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title ChainlinkRoundLib
 * @notice Library that manages Chainlink round parsing.
 */
library ChainlinkRoundLib {
    /// @dev Phase ID offset location in the round ID
    uint256 constant PHASE_OFFSET = 64;

    /**
     * @notice Computes the chainlink phase ID from a round ID
     * @param roundId The round ID
     * @return Chainlink phase ID
     */
    function getPhaseId(uint80 roundId) internal pure returns (uint16) {
        return uint16(roundId >> PHASE_OFFSET);
    }
}
