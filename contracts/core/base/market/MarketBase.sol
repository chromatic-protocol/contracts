// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IUSUMLiquidator} from "@usum/core/interfaces/IUSUMLiquidator.sol";
import {IKeeperFeePayer} from "@usum/core/interfaces/IKeeperFeePayer.sol";
import {LpSlotSet} from "@usum/core/lpslot/LpSlotSet.sol";
import {Position} from "@usum/core/libraries/Position.sol";

abstract contract MarketBase is IUSUMMarket {
    IUSUMMarketFactory public immutable override factory;
    IOracleProvider public immutable override oracleProvider;
    IERC20Metadata public immutable override settlementToken;

    IUSUMLiquidator public immutable override liquidator;
    IKeeperFeePayer public immutable override keeperFeePayer;

    LpSlotSet internal lpSlotSet;

    mapping(uint256 => Position) internal positions;
    
    modifier onlyLiquidator() {
        require(msg.sender == address(liquidator));
        _;
    }

    constructor() {
        factory = IUSUMMarketFactory(msg.sender);

        (address _oracleProvider, address _settlementToken) = factory
            .parameters();

        oracleProvider = IOracleProvider(_oracleProvider);
        settlementToken = IERC20Metadata(_settlementToken);
        liquidator = IUSUMLiquidator(factory.liquidator());
        keeperFeePayer = IKeeperFeePayer(factory.keeperFeePayer());
    }
}
