// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IChromaticMarketFactory} from "@chromatic/core/interfaces/IChromaticMarketFactory.sol";

abstract contract VerifyCallback {
    error NotMarket();

    address marketFactory;

    modifier verifyCallback() {
        if (!IChromaticMarketFactory(marketFactory).isRegisteredMarket(msg.sender)) revert NotMarket();
        _;
    }
}
