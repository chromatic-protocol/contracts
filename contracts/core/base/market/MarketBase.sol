// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {LpSlotSet} from "@usum/core/lpslot/LpSlotSet.sol";
import {Position} from "@usum/core/libraries/Position.sol";

abstract contract MarketBase is IUSUMMarket {
    IUSUMMarketFactory public immutable override factory;
    IOracleProvider public immutable override oracleProvider;
    IERC20Metadata public immutable override settlementToken;
    LpSlotSet internal lpSlotSet;

    mapping(uint256 => Position) internal positions;

    constructor() {
        factory = IUSUMMarketFactory(msg.sender);

        (address _oracleProvider, address _settlementToken) = factory
            .parameters();

        oracleProvider = IOracleProvider(_oracleProvider);
        settlementToken = IERC20Metadata(_settlementToken);
    }
}
