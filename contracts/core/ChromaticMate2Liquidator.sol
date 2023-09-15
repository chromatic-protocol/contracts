// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticLiquidator} from "@chromatic-protocol/contracts/core/interfaces/IChromaticLiquidator.sol";
import {Mate2Liquidator} from "@chromatic-protocol/contracts/core/keeper/Mate2Liquidator.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/base/gelato/AutomateReady.sol";
import {IMate2Automation} from "@chromatic-protocol/contracts/core/keeper/IMate2Automation.sol";
import {IMate2Automate} from "@chromatic-protocol/contracts/core/keeper/IMate2Automate.sol";

/**
 * @title ChromaticMate2Liquidator
 * @dev A contract that handles the liquidation and claiming of positions in Chromatic markets.
 *      It extends the Mate2Liquidator contracts and implements the IChromaticLiquidator interface.
 */
contract ChromaticMate2Liquidator is Mate2Liquidator {
    IMate2Automate immutable automate;

    /**
     * @dev Constructor function.
     * @param _factory The address of the Chromatic Market Factory contract.
     * @param _automate The address of the Mate2 Automate contract.
     */
    constructor(
        IChromaticMarketFactory _factory,
        address _automate
    )
        // address opsProxyFactory
        Mate2Liquidator(_factory)
    {
        automate = IMate2Automate(_automate);
    }

    /**
     * @inheritdoc Mate2Liquidator
     */
    function getAutomate() internal view override returns (IMate2Automate) {
        return IMate2Automate(automate);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     */
    function liquidate(address market, uint256 positionId) external override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        uint256 fee = automate.getPerformUpkeepFee();
        _liquidate(market, positionId, fee);
    }

    /**
     * @inheritdoc IChromaticLiquidator
     */
    function claimPosition(address market, uint256 positionId) external override {
        // feeToken is the native token because ETH is set as a fee token when creating task
        uint256 fee = automate.getPerformUpkeepFee();
        _claimPosition(market, positionId, fee);
    }
}
