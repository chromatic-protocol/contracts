// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IVaultEarningDistributor} from "@chromatic-protocol/contracts/core/interfaces/IVaultEarningDistributor.sol";
import {IMate2Automation} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2Automation.sol";
import {IMate2AutomationRegistry} from "@chromatic-protocol/contracts/core/automation/mate2/IMate2AutomationRegistry.sol";
import {VaultEarningDistributorBase} from "@chromatic-protocol/contracts/core/automation/VaultEarningDistributorBase.sol";

contract Mate2VaultEarningDistributor is VaultEarningDistributorBase, IMate2Automation {
    IMate2AutomationRegistry public immutable automate;

    mapping(address => uint256) public makerEarningDistributionUpkeepIds; // settlement token => upkeep id
    mapping(address => uint256) public marketEarningDistributionUpkeepIds; // market => upkeep id

    enum UpkeepType {
        MakerEarningDistribution,
        MarketEarningDistribution
    }

    constructor(
        IChromaticMarketFactory _factory,
        address _automate
    ) VaultEarningDistributorBase(_factory) {
        automate = IMate2AutomationRegistry(_automate);
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
            1e6, //uint32 gasLimit,
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
            try automate.cancelUpkeep(upkeepId) {} catch {
                // ignore
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
            1e6, //uint32 gasLimit,
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
            try automate.cancelUpkeep(upkeepId) {} catch {
                // ignore
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
}
