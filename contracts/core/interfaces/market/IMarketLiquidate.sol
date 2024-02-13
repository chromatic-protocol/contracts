// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;


/**
 * @title IMarketLiquidate
 * @dev Interface for liquidating and claiming positions in a market.
 */
interface IMarketLiquidate {
    /**
     * @dev Checks if a position is eligible for liquidation.
     * @param positionId The ID of the position to check.
     * @return A boolean indicating if the position is eligible for liquidation.
     */
    function checkLiquidation(uint256 positionId) external view returns (bool);

    /**
     * @dev Liquidates a position.
     * @param positionId The ID of the position to liquidate.
     * @param keeper The address of the keeper performing the liquidation.
     * @param keeperFee The native token amount of the keeper's fee.
     */
    function liquidate(uint256 positionId, address keeper, uint256 keeperFee) external;

    /**
     * @dev Checks if a position is eligible for claim.
     * @param positionId The ID of the position to check.
     * @return A boolean indicating if the position is eligible for claim.
     */
    function checkClaimPosition(uint256 positionId) external view returns (bool);

    /**
     * @dev Claims a closed position on behalf of a keeper.
     * @param positionId The ID of the position to claim.
     * @param keeper The address of the keeper claiming the position.
     * @param keeperFee The native token amount of the keeper's fee.
     */
    function claimPosition(uint256 positionId, address keeper, uint256 keeperFee) external;
}
