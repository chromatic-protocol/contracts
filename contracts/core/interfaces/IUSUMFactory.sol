// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IMarketDeployer} from "./IMarketDeployer.sol";
import {IOracleRegistry} from "./IOracleRegistry.sol";

interface IUSUMFactory {

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
