// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IMarketDeployer} from "@usum/core/interfaces/factory/IMarketDeployer.sol";
import {MarketFactoryBase} from "@usum/core/base/factory/MarketFactoryBase.sol";
import {USUMMarket} from "@usum/core/USUMMarket.sol";

abstract contract MarketDeployer is MarketFactoryBase {
    struct Parameters {
        address oracleProvider; // abstract contract vs contract
        address settlementToken;
    }

    /// @inheritdoc IMarketDeployer
    Parameters public override parameters;

    /// @dev Deploys a market with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the market.
    /// @param oracleProvider oracleProvider address
    /// @param settlementToken The settlement token of the market
    function deploy(
        address oracleProvider,
        address settlementToken
    ) internal returns (address market) {
        parameters = Parameters({
            oracleProvider: oracleProvider,
            settlementToken: settlementToken
        });
        market = address(
            new USUMMarket{
                salt: keccak256(abi.encode(oracleProvider, settlementToken))
            }()
        );
        delete parameters;
    }
}
