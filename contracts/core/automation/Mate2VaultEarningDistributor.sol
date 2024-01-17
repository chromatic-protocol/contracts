// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IVaultEarningDistributor} from "@chromatic-protocol/contracts/core/interfaces/IVaultEarningDistributor.sol";
import {IMate2Automation} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation.sol";
import {IMate2AutomationRegistry} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry.sol";
import {VaultEarningDistributorBase} from "@chromatic-protocol/contracts/core/automation/VaultEarningDistributorBase.sol";

contract Mate2VaultEarningDistributor is VaultEarningDistributorBase, IMate2Automation {
    uint32 public constant DEFAULT_UPKEEP_GAS_LIMIT = 1e7;

    IMate2AutomationRegistry public immutable automate;

    uint32 public upkeepGasLimit;
    mapping(address => uint256) public makerEarningDistributionUpkeepIds; // settlement token => upkeep id
    mapping(address => uint256) public marketEarningDistributionUpkeepIds; // market => upkeep id

    enum UpkeepType {
        MakerEarningDistribution,
        MarketEarningDistribution
    }

    event UpkeepGasLimitUpdated(uint32 gasLimitOld, uint32 gasLimitNew);

    constructor(
        IChromaticMarketFactory _factory,
        address _automate
    ) VaultEarningDistributorBase(_factory) {
        automate = IMate2AutomationRegistry(_automate);
        upkeepGasLimit = DEFAULT_UPKEEP_GAS_LIMIT;
    }

    /**
     * @inheritdoc IMate2Automation
     */
    function checkUpkeep(
        bytes calldata checkData
    ) external view returns (bool upkeepNeeded, bytes memory performData) {
        (UpkeepType upkeepType, address tokenOrMarket) = abi.decode(
            checkData,
            (UpkeepType, address)
        );
        if (upkeepType == UpkeepType.MakerEarningDistribution)
            return resolveMakerEarningDistribution(tokenOrMarket);
        else if (upkeepType == UpkeepType.MarketEarningDistribution)
            return resolveMarketEarningDistribution(tokenOrMarket);
    }

    /**
     * @inheritdoc IMate2Automation
     */
    function performUpkeep(bytes calldata performData) external {
        (UpkeepType upkeepType, address tokenOrMarket) = abi.decode(
            performData,
            (UpkeepType, address)
        );
        if (upkeepType == UpkeepType.MakerEarningDistribution)
            distributeMakerEarning(tokenOrMarket);
        else if (upkeepType == UpkeepType.MarketEarningDistribution)
            distributeMarketEarning(tokenOrMarket);
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     * @dev This function can only be called by the Chromatic factory contract or the DAO.
     *      Throws an `ExistMakerEarningDistributionTask` error if a maker earning distribution task already exists for the token.
     */
    function createMakerEarningDistributionTask(address token) external override onlyVault {
        if (makerEarningDistributionUpkeepIds[token] != 0)
            revert ExistMakerEarningDistributionTask();

        makerEarningDistributionUpkeepIds[token] = automate.registerUpkeep(
            address(this),
            upkeepGasLimit,
            address(this), // address admin,
            false, // bool useTreasury,
            false, // bool singleExec,
            abi.encode(UpkeepType.MakerEarningDistribution, token)
        );
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function cancelMakerEarningDistributionTask(address token) external override onlyVault {
        uint256 upkeepId = makerEarningDistributionUpkeepIds[token];
        if (upkeepId != 0) {
            delete makerEarningDistributionUpkeepIds[token];
            try automate.cancelUpkeep(upkeepId) {} catch Error(string memory reason) {
                //slither-disable-next-line reentrancy-events
                emit catchErr("cancelUpkeep", reason);
            }
        }
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function resolveMakerEarningDistribution(
        address token
    ) public view override returns (bool canExec, bytes memory execPayload) {
        if (_makerEarningDistributable(token)) {
            return (true, abi.encode(UpkeepType.MakerEarningDistribution, token));
        }

        return (false, "");
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     * @dev This function can only be called by the Chromatic factory contract or the DAO.
     *      Throws an `ExistMarketEarningDistributionTask` error if a market earning distribution task already exists for the market.
     */
    function createMarketEarningDistributionTask(address market) external override onlyVault {
        if (marketEarningDistributionUpkeepIds[market] != 0)
            revert ExistMarketEarningDistributionTask();

        marketEarningDistributionUpkeepIds[market] = automate.registerUpkeep(
            address(this),
            upkeepGasLimit,
            address(this), // address admin,
            false, // bool useTreasury,
            false, // bool singleExec,
            abi.encode(UpkeepType.MarketEarningDistribution, market)
        );
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function cancelMarketEarningDistributionTask(address market) external override onlyVault {
        uint256 upkeepId = marketEarningDistributionUpkeepIds[market];
        if (upkeepId != 0) {
            delete marketEarningDistributionUpkeepIds[market];
            try automate.cancelUpkeep(upkeepId) {} catch Error(string memory reason) {
                //slither-disable-next-line reentrancy-events
                emit catchErr("cancelUpkeep", reason);
            }
        }
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function resolveMarketEarningDistribution(
        address market
    ) public view override returns (bool canExec, bytes memory execPayload) {
        if (_marketEarningDistributable(market)) {
            return (true, abi.encode(UpkeepType.MarketEarningDistribution, market));
        }

        return (false, "");
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
}
