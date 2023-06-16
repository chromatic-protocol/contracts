// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticLiquidator} from "@chromatic-protocol/contracts/core/interfaces/IChromaticLiquidator.sol";
import {Liquidator} from "@chromatic-protocol/contracts/core/base/Liquidator.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/base/gelato/AutomateReady.sol";
import {IAutomate} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";

/**
 * @title ChromaticLiquidator
 * @dev A contract that handles the liquidation and claiming of positions in Chromatic markets.
 *      It extends the Liquidator and AutomateReady contracts and implements the IChromaticLiquidator interface.
 */
contract ChromaticLiquidator is Liquidator, AutomateReady {
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
    ) Liquidator(_factory) AutomateReady(_automate, address(this), opsProxyFactory) {}

    /**
     * @inheritdoc Liquidator
     */
    function getAutomate() internal view override returns (IAutomate) {
        return automate;
    }

    /**
     * @inheritdoc IChromaticLiquidator
     * @dev Can only be called by the dedicated message sender.
     */
    function liquidate(
        address market,
        uint256 positionId
    ) external override onlyDedicatedMsgSender {
        // feeToken is the native token because ETH is set as a fee token when creating task
        // TODO: need test in goerli
        (uint256 fee, ) = _getFeeDetails();
        _liquidate(market, positionId, fee);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     * @dev Can only be called by the dedicated message sender.
     */
    function claimPosition(
        address market,
        uint256 positionId
    ) external override onlyDedicatedMsgSender {
        // feeToken is the native token because ETH is set as a fee token when creating task
        (uint256 fee, ) = _getFeeDetails();
        _claimPosition(market, positionId, fee);
    }
}
