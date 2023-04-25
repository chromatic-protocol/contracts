// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

abstract contract VerifyCallback {
    error NotMarket();

    address private _callbackMarketAddressInTx;

    modifier verifyCallback() {
        address marketAddress = _callbackMarketAddressInTx;
        delete _callbackMarketAddressInTx;
        if (msg.sender != marketAddress) revert NotMarket();
        _;
    }

    function _prepareMarket(address marketAddress) internal {
        _callbackMarketAddressInTx = marketAddress;
    }
}
