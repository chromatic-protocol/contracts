// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IMarketDeployer} from "@usum/core/interfaces/factory/IMarketDeployer.sol";
import {ISettlementTokenRegistry} from "@usum/core/interfaces/factory/ISettlementTokenRegistry.sol";
import {IOracleRegistry} from "@usum/core/interfaces/IOracleRegistry.sol";

interface IUSUMMarketFactory is IMarketDeployer, ISettlementTokenRegistry {
    event MarketCreated(
        address oracleProvider,
        address settlementToken,
        address market
    );

    function dao() external view returns (address);

    function oracleRegistry() external view returns (IOracleRegistry);

    function getMarket(
        address oracleProvider,
        address settlementToken
    ) external view returns (address market);

    function createMarket(
        address oracleProvider,
        address settlementToken
    ) external;
}
