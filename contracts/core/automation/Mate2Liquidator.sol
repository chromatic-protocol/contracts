// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IMate2Automation1_1, ExtraModule} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation1_1.sol";
import {IMate2AutomationRegistry1_1} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry1_1.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";
import {LiquidatorBase} from "@chromatic-protocol/contracts/core/automation/LiquidatorBase.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IOracleProviderPullBased} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProviderPullBased.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IMarketSettlement} from "@chromatic-protocol/contracts/core/interfaces/IMarketSettlement.sol";
import {OracleProviderLib} from "@chromatic-protocol/contracts/oracle/libraries/OracleProviderLib.sol";

/**
 * @title Mate2Liquidator
 * @dev A contract that handles the liquidation and claiming of positions in Chromatic markets.
 *      It implements the ILiquidator and the IMate2Automation interface.
 */
contract Mate2Liquidator is LiquidatorBase, IMate2Automation1_1 {
    uint32 public constant DEFAULT_UPKEEP_GAS_LIMIT = 1e7;
    uint256 public constant DEFAULT_WAIT_POSITION_CLAIM = 1 days;

    IMate2AutomationRegistry1_1 public immutable automate;

    uint32 public upkeepGasLimit;
    uint256 public waitPositionClaim;

    mapping(address => mapping(uint256 => uint256)) private _liquidationUpkeepIds;
    mapping(address => mapping(uint256 => uint256)) private _claimPositionUpkeepIds;

    enum UpkeepType {
        LiquidatePosition,
        ClaimPosition
    }

    event UpkeepGasLimitUpdated(uint32 gasLimitOld, uint32 gasLimitNew);
    event WaitPositionClaimUpdated(uint256 waitPositionClaimOld, uint256 waitPositionClaimNew);

    /**
     * @dev Constructor function.
     * @param _factory The address of the Chromatic Market Factory contract.
     * @param _automate The address of the Mate2 Automate contract.
     */
    constructor(IChromaticMarketFactory _factory, address _automate) LiquidatorBase(_factory) {
        automate = IMate2AutomationRegistry1_1(_automate);
        upkeepGasLimit = DEFAULT_UPKEEP_GAS_LIMIT;
        waitPositionClaim = DEFAULT_WAIT_POSITION_CLAIM;
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function createLiquidationTask(uint256 positionId) external override onlyMarket {
        _registerUpkeep(_liquidationUpkeepIds, positionId, UpkeepType.LiquidatePosition, 0);
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
        uint256 positionId,
        bytes calldata extraData
    ) public view override returns (bool canExec, bytes memory execPayload) {
        IOracleProvider oracleProvider = IChromaticMarket(_market).oracleProvider();

        bool shouldLiquidate;

        if (OracleProviderLib.isPullBased(oracleProvider)) {
            IOracleProviderPullBased pullBasedOracle = IOracleProviderPullBased(
                address(oracleProvider)
            );
            shouldLiquidate = IMarketLiquidate(_market).checkLiquidationWithOracleVersion(
                positionId,
                pullBasedOracle.parseExtraData(extraData)
            );
        } else {
            shouldLiquidate = IMarketLiquidate(_market).checkLiquidation(positionId);
        }

        if (shouldLiquidate) {
            return (true, abi.encode(_market, positionId, UpkeepType.LiquidatePosition, extraData));
        }

        return (false, bytes(""));
    }

    /**
     * @inheritdoc ILiquidator
     * @dev Can only be called by a registered market.
     */
    function createClaimPositionTask(uint256 positionId) external override onlyMarket {
        _registerUpkeep(
            _claimPositionUpkeepIds,
            positionId,
            UpkeepType.ClaimPosition,
            block.timestamp + waitPositionClaim
        );
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
        uint256 positionId,
        bytes calldata extraData
    ) public view override returns (bool canExec, bytes memory execPayload) {
        if (IMarketLiquidate(_market).checkClaimPosition(positionId)) {
            return (true, abi.encode(_market, positionId, UpkeepType.ClaimPosition, extraData));
        }

        return (false, "");
    }

    /**
     * @dev Internal function to create a Mate2 upkeep for liquidation or claim position.
     * @param registry The mapping to store task IDs.
     * @param positionId The ID of the position.
     * @param executableTime The upkeep executable time.
     */
    function _registerUpkeep(
        mapping(address => mapping(uint256 => uint256)) storage registry,
        uint256 positionId,
        UpkeepType upkeepType,
        uint256 executableTime
    ) internal {
        address market = msg.sender;
        if (registry[market][positionId] != 0) {
            return;
        }

        IOracleProvider oracleProvider = IChromaticMarket(market).oracleProvider();

        ExtraModule extraModule; // = ExtraModule.None;
        bytes memory extraParam; // = bytes("");

        if (OracleProviderLib.isPullBased(oracleProvider)) {
            IOracleProviderPullBased pullBasedOracle = IOracleProviderPullBased(
                address(oracleProvider)
            );
            extraModule = pullBasedOracle.extraModule();
            extraParam = pullBasedOracle.extraParam();
        }

        uint256 upkeepId = automate.registerUpkeep(
            address(this),
            upkeepGasLimit,
            address(this), // address admin,
            false, // bool useTreasury,
            true, // bool singleExec,
            abi.encode(market, positionId, upkeepType, executableTime),
            extraModule,
            extraParam
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

    /**
     * @inheritdoc IMate2Automation1_1
     */
    function checkUpkeep(
        bytes calldata checkData,
        bytes calldata extraData
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        (address market, uint256 positionId, UpkeepType upkeepType, uint256 claimTime) = abi.decode(
            checkData,
            (address, uint256, UpkeepType, uint256)
        );
        if (upkeepType == UpkeepType.LiquidatePosition)
            return resolveLiquidation(market, positionId, extraData);
        else if (upkeepType == UpkeepType.ClaimPosition) {
            if (block.timestamp < claimTime) {
                return (false, bytes(""));
            }
            return resolveClaimPosition(market, positionId, extraData);
        }
    }

    function performUpkeep(bytes memory performData) external {
        (address market, uint256 positionId, UpkeepType upkeepType, bytes memory extraData) = abi
            .decode(performData, (address, uint256, UpkeepType, bytes));
        if (upkeepType == UpkeepType.LiquidatePosition) {
            IOracleProvider oracleProvider = IChromaticMarket(market).oracleProvider();
            if (OracleProviderLib.isPullBased(oracleProvider)) {
                IMarketSettlement(
                    IChromaticMarketFactory(IChromaticMarket(market).factory()).marketSettlement()
                ).updatePrice(market, extraData);
            }
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

    function updateUpkeepGasLimit(uint32 gasLimit) external onlyDao {
        uint32 gasLimitOld = upkeepGasLimit;
        upkeepGasLimit = gasLimit;
        emit UpkeepGasLimitUpdated(gasLimitOld, gasLimit);
    }

    function updateWaitPositionClaim(uint256 _waitPositionClaim) external onlyDao {
        uint256 waitPositionClaimOld = waitPositionClaim;
        waitPositionClaim = _waitPositionClaim;
        emit WaitPositionClaimUpdated(waitPositionClaimOld, _waitPositionClaim);
    }
}
