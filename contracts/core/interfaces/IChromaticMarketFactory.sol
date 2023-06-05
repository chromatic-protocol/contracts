// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IInterestCalculator} from "@chromatic/core/interfaces/IInterestCalculator.sol";
import {IMarketDeployer} from "@chromatic/core/interfaces/factory/IMarketDeployer.sol";
import {ISettlementTokenRegistry} from "@chromatic/core/interfaces/factory/ISettlementTokenRegistry.sol";
import {IOracleProviderRegistry} from "@chromatic/core/interfaces/factory/IOracleProviderRegistry.sol";

interface IChromaticMarketFactory is
    IMarketDeployer,
    IOracleProviderRegistry,
    ISettlementTokenRegistry,
    IInterestCalculator
{
    event UpdateDao(address indexed dao);
    event UpdateTreasury(address indexed treasury);
    event SetLiquidator(address indexed liquidator);
    event SetVault(address indexed vault);
    event SetKeeperFeePayer(address indexed keeperFeePayer);

    event MarketCreated(
        address indexed oracleProvider,
        address indexed settlementToken,
        address indexed market
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

    function getMarket(
        address oracleProvider,
        address settlementToken
    ) external view returns (address);

    function createMarket(address oracleProvider, address settlementToken) external;

    function isRegisteredMarket(address market) external view returns (bool);

    function createMakerEarningDistributionTask(address token) external;

    function cancelMakerEarningDistributionTask(address token) external;

    function createMarketEarningDistributionTask(address market) external;

    function cancelMarketEarningDistributionTask(address market) external;
}
