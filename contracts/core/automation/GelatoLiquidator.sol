// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/automation/gelato/AutomateReady.sol";
import {ModuleData, Module, TriggerType, IAutomate, IGelato} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {LiquidatorBase} from "@chromatic-protocol/contracts/core/automation/LiquidatorBase.sol";

/**
 * @title GelatoLiquidator
 * @dev A contract that handles the liquidation and claiming of positions in Chromatic markets.
 *      It extends the AutomateReady contracts and implements the ILiquidator interface.
 */
contract GelatoLiquidator is LiquidatorBase, AutomateReady {
    uint256 private constant WAIT_POSITION_CLAIM = 1 days;

    uint256 public waitPositionClaim;

    mapping(address => mapping(uint256 => bytes32)) private _liquidationTaskIds;
    mapping(address => mapping(uint256 => bytes32)) private _claimPositionTaskIds;

    /**
     * @notice Emitted when the waiting time of the claim task is updated.
     * @param waitingTime The new waiting time of the claim task.
     */
    event WaitPositionClaimUpdated(uint256 indexed waitingTime);

    /**
     * @dev Constructor function.
     * @param _factory The address of the Chromatic Market Factory contract.
     * @param _automate The address of the Gelato Automate contract.
     */
    constructor(
        IChromaticMarketFactory _factory,
        address _automate
    ) LiquidatorBase(_factory) AutomateReady(_automate, address(this)) {
        waitPositionClaim = WAIT_POSITION_CLAIM;
    }

    /**
     * @notice Updates the waiting time of the claim task.
     * @param waitingTime The new waiting time of the claim task.
     */
    function updateWaitPositionClaim(uint256 waitingTime) external onlyDao {
        waitPositionClaim = waitingTime;
        emit WaitPositionClaimUpdated(waitingTime);
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function createLiquidationTask(uint256 positionId) external override onlyMarket {
        address market = msg.sender;
        if (_liquidationTaskIds[market][positionId] != bytes32(0)) {
            return;
        }

        ModuleData memory moduleData = ModuleData({modules: new Module[](4), args: new bytes[](4)});

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.PROXY;
        moduleData.modules[2] = Module.SINGLE_EXEC;
        moduleData.modules[3] = Module.TRIGGER;
        moduleData.args[0] = abi.encode(
            address(this),
            abi.encodeCall(this.resolveLiquidation, (market, positionId, ""))
        );
        moduleData.args[1] = bytes("");
        moduleData.args[2] = bytes("");
        moduleData.args[3] = abi.encode(TriggerType.BLOCK, bytes(""));

        _liquidationTaskIds[market][positionId] = automate.createTask(
            address(this),
            abi.encode(this.liquidate.selector),
            moduleData,
            ETH
        );
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function cancelLiquidationTask(uint256 positionId) external override onlyMarket {
        _cancelTask(_liquidationTaskIds, positionId);
    }

    /**
     * @inheritdoc ILiquidator
     */
    function resolveLiquidation(
        address _market,
        uint256 positionId,
        bytes calldata /* extraData */
    ) external view override returns (bool canExec, bytes memory execPayload) {
        if (IMarketLiquidate(_market).checkLiquidation(positionId)) {
            return (true, abi.encodeCall(this.liquidate, (_market, positionId)));
        }

        return (false, bytes(""));
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function createClaimPositionTask(uint256 positionId) external override onlyMarket {
        address market = msg.sender;
        if (_claimPositionTaskIds[market][positionId] != bytes32(0)) {
            return;
        }

        ModuleData memory moduleData = ModuleData({modules: new Module[](4), args: new bytes[](4)});

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.PROXY;
        moduleData.modules[2] = Module.SINGLE_EXEC;
        moduleData.modules[3] = Module.TRIGGER;
        moduleData.args[0] = abi.encode(
            address(this),
            abi.encodeCall(this.resolveClaimPosition, (market, positionId, ""))
        );
        moduleData.args[1] = bytes("");
        moduleData.args[2] = bytes("");
        moduleData.args[3] = abi.encode(
            TriggerType.TIME,
            abi.encode(uint128(block.timestamp + waitPositionClaim), uint128(waitPositionClaim))
        );

        _claimPositionTaskIds[market][positionId] = automate.createTask(
            address(this),
            abi.encode(this.liquidate.selector),
            moduleData,
            ETH
        );
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function cancelClaimPositionTask(uint256 positionId) external override onlyMarket {
        _cancelTask(_claimPositionTaskIds, positionId);
    }

    /**
     * @inheritdoc ILiquidator
     */
    function resolveClaimPosition(
        address _market,
        uint256 positionId,
        bytes calldata /* extraData */
    ) external view override returns (bool canExec, bytes memory execPayload) {
        if (IMarketLiquidate(_market).checkClaimPosition(positionId)) {
            return (true, abi.encodeCall(this.claimPosition, (_market, positionId)));
        }

        return (false, "");
    }

    // for management
    function cancelGelatoTask(bytes32 taskId) external onlyDao {
        automate.cancelTask(taskId);
    }

    /**
     * @dev Internal function to cancel a Gelato task.
     * @param registry The mapping storing task IDs.
     * @param positionId The ID of the position.
     */
    function _cancelTask(
        mapping(address => mapping(uint256 => bytes32)) storage registry,
        uint256 positionId
    ) internal {
        address market = msg.sender;
        bytes32 taskId = registry[market][positionId];
        if (taskId != bytes32(0)) {
            delete registry[market][positionId];
            try automate.cancelTask(taskId) {
                emit CancelTaskSucceeded(taskId);
            } catch {
                emit CancelTaskFailed(taskId);
            }
        }
    }

    function getLiquidationTaskId(
        address market,
        uint256 positionId
    ) external view returns (bytes32 taskId) {
        taskId = _liquidationTaskIds[market][positionId];
    }

    function getClaimPositionTaskId(
        address market,
        uint256 positionId
    ) external view returns (bytes32 taskId) {
        taskId = _claimPositionTaskIds[market][positionId];
    }

    function _getFeeInfo() internal view override returns (uint256 fee, address feePayee) {
        (fee, ) = _getFeeDetails();
        feePayee = IGelato(automate.gelato()).feeCollector();
    }
}
