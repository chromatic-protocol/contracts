// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title ILiquidator
 * @dev Interface for the Chromatic Liquidator contract.
 */
interface ILiquidator {
    /**
     * @notice Creates a liquidation task for a given position.
     * @param positionId The ID of the position to be liquidated.
     */
    function createLiquidationTask(uint256 positionId) external;

    /**
     * @notice Cancels a liquidation task for a given position.
     * @param positionId The ID of the position for which to cancel the liquidation task.
     */
    function cancelLiquidationTask(uint256 positionId) external;

    /**
     * @notice Resolves the liquidation of a position.
     * @dev This function is called by the automation system.
     * @param market The address of the market contract.
     * @param positionId The ID of the position to be liquidated.
     * @param extraData passed by keeper for passing offchain data
     * @return canExec Whether the liquidation can be executed.
     * @return execPayload The encoded function call to execute the liquidation.
     */
    function resolveLiquidation(
        address market,
        uint256 positionId,
        bytes calldata extraData
    ) external view returns (bool canExec, bytes memory execPayload);

    /**
     * @notice Liquidates a position in a market.
     * @param market The address of the market contract.
     * @param positionId The ID of the position to be liquidated.
     */
    function liquidate(address market, uint256 positionId) external;

    /**
     * @notice Creates a claim position task for a given position.
     * @param positionId The ID of the position to be claimed.
     */
    function createClaimPositionTask(uint256 positionId) external;

    /**
     * @notice Cancels a claim position task for a given position.
     * @param positionId The ID of the position for which to cancel the claim position task.
     */
    function cancelClaimPositionTask(uint256 positionId) external;

    /**
     * @notice Resolves the claim of a position.
     * @dev This function is called by the automation system.
     * @param market The address of the market contract.
     * @param positionId The ID of the position to be claimed.
     * @param extraData passed by keeper for passing offchain data
     * @return canExec Whether the claim can be executed.
     * @return execPayload The encoded function call to execute the claim.
     */
    function resolveClaimPosition(
        address market,
        uint256 positionId,
        bytes calldata extraData
    ) external view returns (bool canExec, bytes memory execPayload);

    /**
     * @notice Claims a position in a market.
     * @param market The address of the market contract.
     * @param positionId The ID of the position to be claimed.
     */
    function claimPosition(address market, uint256 positionId) external;

    function getLiquidationTaskId(
        address market,
        uint256 positionId
    ) external view returns (bytes32);

    function getClaimPositionTaskId(
        address market,
        uint256 positionId
    ) external view returns (bytes32);
}
