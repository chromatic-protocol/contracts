// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";

abstract contract LiquidatorBase is ILiquidator {
    IChromaticMarketFactory public immutable factory;

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
     */
    constructor(IChromaticMarketFactory _factory) {
        factory = _factory;
    }

    /**
     * @inheritdoc ILiquidator
     */
    function liquidate(
        address market,
        uint256 positionId
    ) public override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        (uint256 fee, address feePayee) = _getFeeInfo();
        IMarketLiquidate(market).liquidate(positionId, feePayee, fee);
    }

    /**
     * @inheritdoc ILiquidator
     */
    function claimPosition(address market, uint256 positionId) public override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        (uint256 fee, address feePayee) = _getFeeInfo();
        IMarketLiquidate(market).claimPosition(positionId, feePayee, fee);
    }

    function _getFeeInfo() internal view virtual returns (uint256 fee, address feePayee);
}
