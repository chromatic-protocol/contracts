// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";

/**
 * @title VerifyCallback
 * @dev Abstract contract for verifying callback functions from registered markets.
 */
abstract contract VerifyCallback {
    address marketFactory;

    /**
     * @dev Throws an error indicating that the caller is not a registered market.
     */
    error NotMarket();

    /**
     * @dev Modifier to verify the callback function is called by a registered market.
     *      Throws an error if the caller is not a registered market.
     */
    modifier verifyCallback() {
        if (!IChromaticMarketFactory(marketFactory).isRegisteredMarket(msg.sender))
            revert NotMarket();
        _;
    }
}
