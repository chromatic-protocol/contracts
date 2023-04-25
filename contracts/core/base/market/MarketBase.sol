// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMFactory} from "@usum/core/interfaces/IUSUMFactory.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {LpSlotSet} from "@usum/core/libraries/LpSlotSet.sol";
import {Position} from "@usum/core/libraries/Position.sol";

abstract contract MarketBase is IUSUMMarket {
    IUSUMFactory public immutable override factory;
    IOracleProvider public immutable override oracleProvider;
    IERC20Metadata public immutable override settlementToken;
    LpSlotSet internal lpSlotSet;

    mapping(uint256 => Position) internal positions;
    // liquidity
    // uint256 internal lpReserveRatio;

    modifier onlyDao() {
        // TODO
        // require(msg.sender == factory.dao());
        _;
    }

    constructor() {
        factory = IUSUMFactory(msg.sender);

        (address _oracleProvider, address _settlementToken) = factory
            .parameters();

        oracleProvider = IOracleProvider(_oracleProvider);
        settlementToken = IERC20Metadata(_settlementToken);
    }
}
