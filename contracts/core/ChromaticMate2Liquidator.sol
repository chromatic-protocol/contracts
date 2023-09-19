// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticLiquidator} from "@chromatic-protocol/contracts/core/interfaces/IChromaticLiquidator.sol";
import {IMate2Automation} from "@chromatic-protocol/contracts/core/keeper/IMate2Automation.sol";
import {IMate2Automate} from "@chromatic-protocol/contracts/core/keeper/IMate2Automate.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";

/**
 * @title ChromaticMate2Liquidator
 * @dev A contract that handles the liquidation and claiming of positions in Chromatic markets.
 *      It implements the IChromaticLiquidator and the IMate2Automation interface.
 */
contract ChromaticMate2Liquidator is IChromaticLiquidator, IMate2Automation {
    IMate2Automate immutable automate;
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant DEFAULT_LIQUIDATION_INTERVAL = 1 minutes;
    uint256 private constant DEFAULT_CLAIM_INTERVAL = 1 days;

    IChromaticMarketFactory immutable factory;
    uint256 public liquidationInterval;
    uint256 public claimInterval;

    mapping(address => mapping(uint256 => bytes32)) private _liquidationTaskIds;
    mapping(address => mapping(uint256 => bytes32)) private _claimPositionTaskIds;

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
        liquidationInterval = DEFAULT_LIQUIDATION_INTERVAL;
        claimInterval = DEFAULT_CLAIM_INTERVAL;
        automate = IMate2Automate(_automate);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     * @dev Can only be called by the DAO
     */
    function updateLiquidationInterval(uint256 interval) external override {
        liquidationInterval = interval;
        emit UpdateLiquidationInterval(interval);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     * @dev Can only be called by the DAO
     */
    function updateClaimInterval(uint256 interval) external override {
        claimInterval = interval;
        emit UpdateClaimInterval(interval);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     * @dev Can only be called by a registered market.
     */
    function createLiquidationTask(uint256 positionId) external override onlyMarket {
        _registerUpkeep(
            _liquidationTaskIds,
            positionId,
            UpkeepType.LiquidatePosition,
            liquidationInterval
        );
    }

    /**
     * @inheritdoc IChromaticLiquidator
     * @dev Can only be called by a registered market.
     */
    function cancelLiquidationTask(uint256 positionId) external override onlyMarket {
        _cancelTask(_liquidationTaskIds, positionId);
    }

    /**
     * @inheritdoc IChromaticLiquidator
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
     * @inheritdoc IChromaticLiquidator
     * @dev Can only be called by a registered market.
     */
    function createClaimPositionTask(uint256 positionId) external override onlyMarket {
        _registerUpkeep(_claimPositionTaskIds, positionId, UpkeepType.ClaimPosition, claimInterval);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     * @dev Can only be called by a registered market.
     */
    function cancelClaimPositionTask(uint256 positionId) external override onlyMarket {
        _cancelTask(_claimPositionTaskIds, positionId);
    }

    /**
     * @inheritdoc IChromaticLiquidator
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
     * @param interval The interval between task executions.
     */
    function _registerUpkeep(
        mapping(address => mapping(uint256 => bytes32)) storage registry,
        uint256 positionId,
        UpkeepType upkeepType,
        uint256 interval
    ) internal {
        address market = msg.sender;
        if (registry[market][positionId] != bytes32(0)) {
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

        registry[market][positionId] = bytes32(upkeepId);
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
            getAutomate().cancelUpkeep(uint256(taskId));
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
    ) external view returns (bytes32 taskId) {
        taskId = _liquidationTaskIds[market][positionId];
    }

    function getClaimPositionTaskId(
        address market,
        uint256 positionId
    ) external view returns (bytes32 taskId) {
        taskId = _claimPositionTaskIds[market][positionId];
    }

    /**
     * @dev Retrieves the IAutomate contract instance.
     * @return IMate2Automate The IMate2Automate contract instance.
     */
    function getAutomate() internal view returns (IMate2Automate) {
        return IMate2Automate(automate);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     */
    function liquidate(address market, uint256 positionId) external override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        uint256 fee = automate.getPerformUpkeepFee();
        IMarketLiquidate(market).liquidate(positionId, address(getAutomate()), fee);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     */
    function claimPosition(address market, uint256 positionId) external override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        uint256 fee = automate.getPerformUpkeepFee();
        IMarketLiquidate(market).claimPosition(positionId, address(getAutomate()), fee);
    }
}
