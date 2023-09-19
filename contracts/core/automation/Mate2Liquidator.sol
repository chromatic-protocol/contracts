// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IMate2Automation} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation.sol";
import {IMate2AutomationRegistry} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";

/**
 * @title Mate2Liquidator
 * @dev A contract that handles the liquidation and claiming of positions in Chromatic markets.
 *      It implements the ILiquidator and the IMate2Automation interface.
 */
contract Mate2Liquidator is ILiquidator, IMate2Automation {
    IMate2AutomationRegistry immutable automate;
    IChromaticMarketFactory immutable factory;

    mapping(address => mapping(uint256 => uint256)) private _liquidationUpkeepIds;
    mapping(address => mapping(uint256 => uint256)) private _claimPositionUpkeepIds;

    enum UpkeepType {
        LiquidatePosition,
        ClaimPosition
    }

    /**
     * @dev Throws an error indicating that the caller is not the DAO.
     */
    error OnlyAccessableByDao();

    /**
     * @dev Throws an error indicating that the caller is not a registered market.
     */
    error OnlyAccessableByMarket();

    /**
     * @dev Modifier to restrict access to only the DAO.
     *      Throws an `OnlyAccessableByDao` error if the caller is not the DAO.
     */
    modifier onlyDao() {
        if (msg.sender != factory.dao()) revert OnlyAccessableByDao();
        _;
    }

    /**
     * @dev Modifier to check if the calling contract is a registered market.
     *      Throws an `OnlyAccessableByMarket` error if the caller is not a registered market.
     */
    modifier onlyMarket() {
        if (!factory.isRegisteredMarket(msg.sender)) revert OnlyAccessableByMarket();
        _;
    }

    /**
     * @dev Constructor function.
     * @param _factory The address of the Chromatic Market Factory contract.
     * @param _automate The address of the Mate2 Automate contract.
     */
    constructor(IChromaticMarketFactory _factory, address _automate) {
        factory = _factory;
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
        _cancelTask(_liquidationUpkeepIds, positionId);
    }

    /**
     * @inheritdoc ILiquidator
     */
    function resolveLiquidation(
        address _market,
        uint256 positionId
    ) external view override returns (bool canExec, bytes memory execPayload) {
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
        _cancelTask(_claimPositionUpkeepIds, positionId);
    }

    /**
     * @inheritdoc ILiquidator
     */
    function resolveClaimPosition(
        address _market,
        uint256 positionId
    ) external view override returns (bool canExec, bytes memory execPayload) {
        if (IMarketLiquidate(_market).checkClaimPosition(positionId)) {
            return (true, abi.encode(_market, positionId, UpkeepType.ClaimPosition));
        }

        return (false, "");
    }

    /**
     * @dev Internal function to perform the claim of a position.
     * @param _market The address of the market contract.
     * @param positionId The ID of the position to be claimed.
     * @param fee The fee to be paid for the claim.
     */
    function _claimPosition(address _market, uint256 positionId, uint256 fee) internal {
        IMarketLiquidate market = IMarketLiquidate(_market);
        market.claimPosition(positionId, address(getAutomate()), fee);
    }

    /**
     * @dev Internal function to create a Gelato task for liquidation or claim position.
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

        uint256 upkeepId = getAutomate().registerUpkeep(
            address(this),
            1e6, //uint32 gasLimit,
            msg.sender, // address admin,
            false, // bool useTreasury,
            true, // bool singleExec,
            abi.encode(market, positionId, upkeepType)
        );

        registry[market][positionId] = upkeepId;
    }

    /**
     * @dev Internal function to cancel a Gelato task.
     * @param registry The mapping storing task IDs.
     * @param positionId The ID of the position.
     */
    function _cancelTask(
        mapping(address => mapping(uint256 => uint256)) storage registry,
        uint256 positionId
    ) internal {
        address market = msg.sender;
        uint256 upkeepId = registry[market][positionId];
        if (upkeepId != 0) {
            getAutomate().cancelUpkeep(upkeepId);
            delete registry[market][positionId];
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
            return this.resolveLiquidation(market, positionId);
        else if (upkeepType == UpkeepType.ClaimPosition)
            return this.resolveClaimPosition(market, positionId);
    }

    function performUpkeep(bytes memory performData) external {
        (address market, uint256 positionId, ) = abi.decode(
            performData,
            (address, uint256, UpkeepType)
        );
        this.liquidate(market, positionId);
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

    /**
     * @dev Retrieves the IAutomate contract instance.
     * @return IMate2AutomationRegistry The IMate2AutomationRegistry contract instance.
     */
    function getAutomate() internal view returns (IMate2AutomationRegistry) {
        return IMate2AutomationRegistry(automate);
    }

    /**
     * @inheritdoc ILiquidator
     */
    function liquidate(address market, uint256 positionId) external override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        uint256 fee = automate.getPerformUpkeepFee();
        IMarketLiquidate(market).liquidate(positionId, address(getAutomate()), fee);
    }

    /**
     * @inheritdoc ILiquidator
     */
    function claimPosition(address market, uint256 positionId) external override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        uint256 fee = automate.getPerformUpkeepFee();
        IMarketLiquidate(market).claimPosition(positionId, address(getAutomate()), fee);
    }
}
