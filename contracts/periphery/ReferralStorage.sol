// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IReferralStorage} from "@chromatic-protocol/contracts/periphery/interfaces/IReferralStorage.sol";

contract ReferralStorage is IReferralStorage {
    mapping(address trader => address referrer) public override referredBy;

    address public immutable router;

    error OnlyAccessableByRouter();

    modifier onlyRouter() {
        if (msg.sender != router) revert OnlyAccessableByRouter();
        _;
    }

    constructor(address router_) {
        require(router_ != address(0));
        router = router_;
    }

    function setReferrer(address trader, address referrer) external override onlyRouter {
        if (
            trader != address(0) &&
            referrer != address(0) &&
            trader != referrer &&
            referredBy[trader] == address(0)
        ) {
            referredBy[trader] = referrer;
            emit ReferrerSet(trader, referrer);
        }
    }
}
