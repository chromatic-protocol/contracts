// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";

abstract contract VerifyCallback {
    error NotMarket();

    address marketFactory;

    modifier verifyCallback() {
        if (!IUSUMMarketFactory(marketFactory).isRegisteredMarket(msg.sender)) revert NotMarket();
        _;
    }
}
