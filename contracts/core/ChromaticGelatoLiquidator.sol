// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticLiquidator} from "@chromatic-protocol/contracts/core/interfaces/IChromaticLiquidator.sol";
import {GelatoLiquidator} from "@chromatic-protocol/contracts/core/keeper/GelatoLiquidator.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/base/gelato/AutomateReady.sol";
import {ModuleData, Module, IAutomate} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";

/**
 * @title ChromaticLiquidator
 * @dev A contract that handles the liquidation and claiming of positions in Chromatic markets.
 *      It extends the Liquidator and AutomateReady contracts and implements the IChromaticLiquidator interface.
 */
contract ChromaticGelatoLiquidator is GelatoLiquidator, AutomateReady {
    /**
     * @dev Constructor function.
     * @param _factory The address of the Chromatic Market Factory contract.
     * @param _automate The address of the Gelato Automate contract.
     * @param opsProxyFactory The address of the Ops Proxy Factory contract.
     */
    constructor(
        IChromaticMarketFactory _factory,
        address _automate,
        address opsProxyFactory
    ) GelatoLiquidator(_factory) AutomateReady(_automate, address(this), opsProxyFactory) {}

    /**
     * @inheritdoc GelatoLiquidator
     */
    function getAutomate() internal view override returns (IAutomate) {
        return automate;
    }

    /**
     * @inheritdoc IChromaticLiquidator
     */
    function liquidate(address market, uint256 positionId) external override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        (uint256 fee, ) = _getFeeDetails();
        _liquidate(market, positionId, fee);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     */
    function claimPosition(address market, uint256 positionId) external override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        (uint256 fee, ) = _getFeeDetails();
        _claimPosition(market, positionId, fee);
    }
}
