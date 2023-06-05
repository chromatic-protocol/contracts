// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IChromaticLiquidator {
    function createLiquidationTask(uint256 positionId) external;

    function cancelLiquidationTask(uint256 positionId) external;

    function resolveLiquidation(
        address market,
        uint256 positionId
    ) external view returns (bool canExec, bytes memory execPayload);

    function liquidate(address market, uint256 positionId) external;

    function createClaimPositionTask(uint256 positionId) external;

    function cancelClaimPositionTask(uint256 positionId) external;

    function resolveClaimPosition(
        address market,
        uint256 positionId
    ) external view returns (bool canExec, bytes memory execPayload);

    function claimPosition(address market, uint256 positionId) external;
}
