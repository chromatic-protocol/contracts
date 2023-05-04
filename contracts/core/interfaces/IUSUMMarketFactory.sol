// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IMarketDeployer} from "@usum/core/interfaces/factory/IMarketDeployer.sol";
import {ISettlementTokenRegistry} from "@usum/core/interfaces/factory/ISettlementTokenRegistry.sol";
import {IOracleProviderRegistry} from "@usum/core/interfaces/factory/IOracleProviderRegistry.sol";

interface IUSUMMarketFactory is
    IMarketDeployer,
    IOracleProviderRegistry,
    ISettlementTokenRegistry
{
    event SetKeeperFeePayer(address keeperFeePayer);

    event MarketCreated(
        address oracleProvider,
        address settlementToken,
        address market
    );

    function dao() external view returns (address);

    function liquidator() external view returns (address);

    function keeperFeePayer() external view returns (address);

    function setKeeperFeePayer(address keeperFeePayer) external;
    
    function getMarkets() external view returns (address[] memory market);

    function createMarket(
        address oracleProvider,
        address settlementToken
    ) external;

    function isRegisteredMarket(address market) external view returns (bool);
}
