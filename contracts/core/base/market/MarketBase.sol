// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMFactory} from "@usum/core/interfaces/IUSUMFactory.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IMarketDeployer} from "@usum/core/interfaces/IMarketDeployer.sol";

abstract contract MarketBase is IUSUMMarket {

    IUSUMFactory public immutable override factory;
    IOracleProvider public immutable override oracleProvider;
    IERC20 public immutable override settlementToken;

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
        settlementToken = IERC20(_settlementToken);

        // lpTokenName = string(
        //     abi.encodePacked(
        //         "zsToken (",
        //         underlyingAsset.symbol(),
        //         "/",
        //         settlementToken.symbol(),
        //         ")"
        //     )
        // );
    }
}
