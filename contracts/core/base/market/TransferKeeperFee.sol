// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {MarketBase} from "@usum/core/base/market/MarketBase.sol";

abstract contract TransferKeeperFee is MarketBase {
    // return usedFee
    function transferKeeperFee(
        address keeper,
        uint256 fee,
        uint256 positionId
    ) external override onlyLiquidator returns (uint256 usedFee) {
        // swap to native token
        settlementToken.transfer(
            address(keeperFeePayer),
            positions[positionId].takerMargin
        );
        usedFee = keeperFeePayer.payKeeperFee(
            address(settlementToken),
            fee,
            keeper
        );
    }
}
