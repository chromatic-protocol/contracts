// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IVaultEarningDistributor} from "@chromatic-protocol/contracts/core/interfaces/IVaultEarningDistributor.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/automation/gelato/AutomateReady.sol";
import {ModuleData, Module, TriggerType, IAutomate, IGelato} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {VaultEarningDistributorBase} from "@chromatic-protocol/contracts/core/automation/VaultEarningDistributorBase.sol";

contract GelatoVaultEarningDistributor is VaultEarningDistributorBase, AutomateReady {
    uint256 private constant DISTRIBUTION_INTERVAL = 1 hours;

    mapping(address => bytes32) public makerEarningDistributionTaskIds; // settlement token => task id
    mapping(address => bytes32) public marketEarningDistributionTaskIds; // market => task id

    constructor(
        IChromaticMarketFactory _factory,
        address _automate
    ) VaultEarningDistributorBase(_factory) AutomateReady(_automate, address(this)) {}

    /**
     * @inheritdoc IVaultEarningDistributor
     * @dev This function can only be called by the Chromatic factory contract or the DAO.
     *      Throws an `ExistMakerEarningDistributionTask` error if a maker earning distribution task already exists for the token.
     */
    function createMakerEarningDistributionTask(address token) external override onlyVault {
        if (makerEarningDistributionTaskIds[token] != bytes32(0))
            revert ExistMakerEarningDistributionTask();

        ModuleData memory moduleData = ModuleData({modules: new Module[](3), args: new bytes[](3)});

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.PROXY;
        moduleData.modules[2] = Module.TRIGGER;
        moduleData.args[0] = _resolverModuleArg(
            abi.encodeCall(this.resolveMakerEarningDistribution, (token))
        );
        moduleData.args[1] = _proxyModuleArg();
        moduleData.args[2] = _timeTriggerModuleArg(block.timestamp, DISTRIBUTION_INTERVAL);

        makerEarningDistributionTaskIds[token] = automate.createTask(
            address(this),
            abi.encode(this.distributeMakerEarning.selector),
            moduleData,
            ETH
        );
    }

    // for management
    function cancelGelatoTask(bytes32 taskId) external onlyDao {
        automate.cancelTask(taskId);
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function cancelMakerEarningDistributionTask(address token) external override onlyVault {
        bytes32 taskId = makerEarningDistributionTaskIds[token];
        if (taskId != bytes32(0)) {
            delete makerEarningDistributionTaskIds[token];
            try automate.cancelTask(taskId) {
                emit CancelTaskSucceeded(taskId);
            } catch {
                emit CancelTaskFailed(taskId);
            }
        }
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function resolveMakerEarningDistribution(
        address token
    ) external view override returns (bool canExec, bytes memory execPayload) {
        if (_makerEarningDistributable(token)) {
            return (true, abi.encodeCall(this.distributeMakerEarning, token));
        }

        return (false, "");
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     * @dev This function can only be called by the Chromatic factory contract or the DAO.
     *      Throws an `ExistMarketEarningDistributionTask` error if a market earning distribution task already exists for the market.
     */
    function createMarketEarningDistributionTask(address market) external override onlyVault {
        if (marketEarningDistributionTaskIds[market] != bytes32(0))
            revert ExistMarketEarningDistributionTask();

        ModuleData memory moduleData = ModuleData({modules: new Module[](3), args: new bytes[](3)});

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.PROXY;
        moduleData.modules[2] = Module.TRIGGER;
        moduleData.args[0] = _resolverModuleArg(
            abi.encodeCall(this.resolveMarketEarningDistribution, market)
        );
        moduleData.args[1] = _proxyModuleArg();
        moduleData.args[2] = _timeTriggerModuleArg(block.timestamp, DISTRIBUTION_INTERVAL);

        marketEarningDistributionTaskIds[market] = automate.createTask(
            address(this),
            abi.encode(this.distributeMarketEarning.selector),
            moduleData,
            ETH
        );
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function cancelMarketEarningDistributionTask(address market) external override onlyVault {
        bytes32 taskId = marketEarningDistributionTaskIds[market];
        if (taskId != bytes32(0)) {
            delete marketEarningDistributionTaskIds[market];
            automate.cancelTask(taskId);
        }
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function resolveMarketEarningDistribution(
        address market
    ) external view override returns (bool canExec, bytes memory execPayload) {
        if (_marketEarningDistributable(market)) {
            return (true, abi.encodeCall(this.distributeMarketEarning, market));
        }

        return (false, "");
    }

    function _getFeeInfo() internal view override returns (uint256 fee, address feePayee) {
        (fee, ) = _getFeeDetails();
        feePayee = IGelato(automate.gelato()).feeCollector();
    }

    function _resolverModuleArg(bytes memory _resolverData) internal view returns (bytes memory) {
        return abi.encode(address(this), _resolverData);
    }

    function _timeTriggerModuleArg(
        uint256 _startTime,
        uint256 _interval
    ) internal pure returns (bytes memory) {
        bytes memory triggerConfig = abi.encode(uint128(_startTime), uint128(_interval));
        return abi.encode(TriggerType.TIME, triggerConfig);
    }

    function _proxyModuleArg() internal pure returns (bytes memory) {
        return bytes("");
    }
}
