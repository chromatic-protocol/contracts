// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IMate2Automation} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation.sol";
import {IMate2AutomationRegistry} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";
import {LiquidatorBase} from "@chromatic-protocol/contracts/core/automation/LiquidatorBase.sol";

/**
 * @title Mate2Liquidator
 * @dev A contract that handles the liquidation and claiming of positions in Chromatic markets.
 *      It implements the ILiquidator and the IMate2Automation interface.
 */
contract Mate2Liquidator is LiquidatorBase, IMate2Automation {
    IMate2AutomationRegistry public immutable automate;

    mapping(address => mapping(uint256 => uint256)) private _liquidationUpkeepIds;
    mapping(address => mapping(uint256 => uint256)) private _claimPositionUpkeepIds;

    enum UpkeepType {
        LiquidatePosition,
        ClaimPosition
    }

    /**
     * @dev Constructor function.
     * @param _factory The address of the Chromatic Market Factory contract.
     * @param _automate The address of the Mate2 Automate contract.
     */
    constructor(IChromaticMarketFactory _factory, address _automate) LiquidatorBase(_factory) {
        automate = IMate2AutomationRegistry(_automate);
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function createLiquidationTask(uint256 positionId) external override onlyMarket {
        _registerUpkeep(_liquidationUpkeepIds, positionId, UpkeepType.LiquidatePosition);
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function cancelLiquidationTask(uint256 positionId) external override onlyMarket {
        _cancelUpkeep(_liquidationUpkeepIds, positionId);
    }

    /**
     * @inheritdoc ILiquidator
     */
    function resolveLiquidation(
        address _market,
        uint256 positionId
    ) public view override returns (bool canExec, bytes memory execPayload) {
        if (IMarketLiquidate(_market).checkLiquidation(positionId)) {
            return (true, abi.encode(_market, positionId, UpkeepType.LiquidatePosition));
        }

        return (false, bytes(""));
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function createClaimPositionTask(uint256 positionId) external override onlyMarket {
        _registerUpkeep(_claimPositionUpkeepIds, positionId, UpkeepType.ClaimPosition);
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function cancelClaimPositionTask(uint256 positionId) external override onlyMarket {
        _cancelUpkeep(_claimPositionUpkeepIds, positionId);
    }

    /**
     * @inheritdoc ILiquidator
     */
    function resolveClaimPosition(
        address _market,
        uint256 positionId
    ) public view override returns (bool canExec, bytes memory execPayload) {
        if (IMarketLiquidate(_market).checkClaimPosition(positionId)) {
            return (true, abi.encode(_market, positionId, UpkeepType.ClaimPosition));
        }

        return (false, "");
    }

    /**
     * @dev Internal function to create a Mate2 upkeep for liquidation or claim position.
     * @param registry The mapping to store task IDs.
     * @param positionId The ID of the position.
     */
    function _registerUpkeep(
        mapping(address => mapping(uint256 => uint256)) storage registry,
        uint256 positionId,
        UpkeepType upkeepType
    ) internal {
        address market = msg.sender;
        if (registry[market][positionId] != 0) {
            return;
        }

        uint256 upkeepId = automate.registerUpkeep(
            address(this),
            1e6, //uint32 gasLimit,
            address(this), // address admin,
            false, // bool useTreasury,
            true, // bool singleExec,
            abi.encode(market, positionId, upkeepType)
        );

        registry[market][positionId] = upkeepId;
    }

    /**
     * @dev Internal function to cancel a Mate2 upkeep.
     * @param registry The mapping storing task IDs.
     * @param positionId The ID of the position.
     */
    function _cancelUpkeep(
        mapping(address => mapping(uint256 => uint256)) storage registry,
        uint256 positionId
    ) internal {
        address market = msg.sender;
        uint256 upkeepId = registry[market][positionId];
        if (upkeepId != 0) {
            delete registry[market][positionId];
            try automate.cancelUpkeep(upkeepId) {} catch Error(string memory reason) {
                //slither-disable-next-line reentrancy-events
                emit catchErr("cancelUpkeep", reason);
            }
        }
    }

    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        (address market, uint256 positionId, UpkeepType upkeepType) = abi.decode(
            checkData,
            (address, uint256, UpkeepType)
        );
        if (upkeepType == UpkeepType.LiquidatePosition)
            return resolveLiquidation(market, positionId);
        else if (upkeepType == UpkeepType.ClaimPosition)
            return resolveClaimPosition(market, positionId);
    }

    function performUpkeep(bytes memory performData) external {
        (address market, uint256 positionId, UpkeepType upkeepType) = abi.decode(
            performData,
            (address, uint256, UpkeepType)
        );
        if (upkeepType == UpkeepType.LiquidatePosition) {
            liquidate(market, positionId);
        } else if (upkeepType == UpkeepType.ClaimPosition) {
            claimPosition(market, positionId);
        }
    }

    function getLiquidationTaskId(
        address market,
        uint256 positionId
    ) external view override returns (bytes32 taskId) {
        taskId = bytes32(getLiquidationUpkeepId(market, positionId));
    }

    function getLiquidationUpkeepId(
        address market,
        uint256 positionId
    ) public view returns (uint256 upkeepId) {
        upkeepId = _liquidationUpkeepIds[market][positionId];
    }

    function getClaimPositionTaskId(
        address market,
        uint256 positionId
    ) external view override returns (bytes32 taskId) {
        taskId = bytes32(getClaimPositionUpkeepId(market, positionId));
    }

    function getClaimPositionUpkeepId(
        address market,
        uint256 positionId
    ) public view returns (uint256 upkeepId) {
        upkeepId = _claimPositionUpkeepIds[market][positionId];
    }

    function _getFeeInfo() internal view override returns (uint256 fee, address feePayee) {
        fee = automate.getPerformUpkeepFee();
        feePayee = address(automate);
    }

    // for management
    function cancelUpkeep(uint256 upkeepId) external onlyDao {
        automate.cancelUpkeep(upkeepId);
    }
}
