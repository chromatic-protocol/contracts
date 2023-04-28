// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IMarketDeployer} from "@usum/core/interfaces/factory/IMarketDeployer.sol";
import {ISettlementTokenRegistry} from "@usum/core/interfaces/factory/ISettlementTokenRegistry.sol";
import {IOracleRegistry} from "@usum/core/interfaces/factory/IOracleRegistry.sol";

interface IUSUMMarketFactory is
    IMarketDeployer,
    IOracleRegistry,
    ISettlementTokenRegistry
{
    event MarketCreated(
        address oracleProvider,
        address settlementToken,
        address market
    );

    function dao() external view returns (address);

    function liquidator() external view returns (address);

    function keeperFeePayer() external view returns (address);

    function getMarket(
        address oracleProvider,
        address settlementToken
    ) external view returns (address market);

    function createMarket(
        address oracleProvider,
        address settlementToken
    ) external;
}
