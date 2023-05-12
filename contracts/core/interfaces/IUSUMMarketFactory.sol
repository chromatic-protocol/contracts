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
    event UpdateDao(address dao);
    event UpdateTreasury(address treasury);
    event SetLiquidator(address liquidator);
    event SetVault(address vault);
    event SetKeeperFeePayer(address keeperFeePayer);

    event MarketCreated(
        address oracleProvider,
        address settlementToken,
        address market
    );

    function dao() external view returns (address);

    function treasury() external view returns (address);

    function liquidator() external view returns (address);

    function vault() external view returns (address);

    function keeperFeePayer() external view returns (address);

    function updateDao(address dao) external;

    function updateTreasury(address treasury) external;

    function setLiquidator(address liquidator) external;

    function setVault(address vault) external;

    function setKeeperFeePayer(address keeperFeePayer) external;

    function getMarkets() external view returns (address[] memory market);

    function getMarketsBySettlmentToken(
        address settlementToken
    ) external view returns (address[] memory);

    function createMarket(
        address oracleProvider,
        address settlementToken
    ) external;

    function isRegisteredMarket(address market) external view returns (bool);

    function createMakerEarningDistributionTask(address token) external;

    function cancelMakerEarningDistributionTask(address token) external;

    function createMarketEarningDistributionTask(address market) external;

    function cancelMarketEarningDistributionTask(address market) external;
}
