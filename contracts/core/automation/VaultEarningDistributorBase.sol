// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IVaultEarningDistributor} from "@chromatic-protocol/contracts/core/interfaces/IVaultEarningDistributor.sol";

abstract contract VaultEarningDistributorBase is IVaultEarningDistributor {
    IChromaticMarketFactory public immutable factory;

    /**
     * @dev Throws an error indicating that the caller is not the chromatch vault contract.
     */
    error OnlyAccessableByVault();

    /**
     * @dev Throws an error indicating that a maker earning distribution task already exists.
     */
    error ExistMakerEarningDistributionTask();

    /**
     * @dev Throws an error indicating that a market earning distribution task already exists.
     */
    error ExistMarketEarningDistributionTask();

    /**
     * @dev Modifier to restrict a function to be called only by the vault contract.
     *      Throws an `OnlyAccessableByVault` error if the caller is not the chromatic vault contract.
     */
    modifier onlyVault() {
        if (msg.sender != factory.vault()) revert OnlyAccessableByVault();
        _;
    }

    constructor(IChromaticMarketFactory _factory) {
        factory = _factory;
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function distributeMakerEarning(address token) public override {
        (uint256 fee, address feePayee) = _getFeeInfo();
        IChromaticVault(factory.vault()).distributeMakerEarning(token, fee, feePayee);
    }

    /**
     * @inheritdoc IVaultEarningDistributor
     */
    function distributeMarketEarning(address market) public override {
        (uint256 fee, address feePayee) = _getFeeInfo();
        IChromaticVault(factory.vault()).distributeMarketEarning(market, fee, feePayee);
    }

    function _getFeeInfo() internal view virtual returns (uint256 fee, address feePayee);

    /**
     * @dev Internal function to check if the maker earning is distributable for a token.
     * @param token The address of the settlement token.
     * @return True if the maker earning is distributable, False otherwise.
     */
    function _makerEarningDistributable(address token) internal view returns (bool) {
        return
            IChromaticVault(factory.vault()).pendingMakerEarnings(token) >=
            factory.getEarningDistributionThreshold(token);
    }

    /**
     * @dev Internal function to check if the market earning is distributable for a market.
     * @param market The address of the market.
     * @return True if the market earning is distributable, False otherwise.
     */
    function _marketEarningDistributable(address market) internal view returns (bool) {
        address token = address(IChromaticMarket(market).settlementToken());
        return
            IChromaticVault(factory.vault()).pendingMarketEarnings(market) >=
            factory.getEarningDistributionThreshold(token);
    }
}
