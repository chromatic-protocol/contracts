// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IMarketDeployer} from "../interfaces/IMarketDeployer.sol";
import {USUMMarket} from "../USUMMarket.sol";

abstract contract MarketDeployer is IMarketDeployer {
    struct Parameters {
        address oracleProvider; // abstract contract vs contract
        address settlementToken;
        string lpTokenUri;
    }

    /// @inheritdoc IMarketDeployer
    Parameters public override parameters;

    /// @dev Deploys a market with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the market.
    /// @param oracleProvider oracleProvider address
    /// @param settlementToken The settlement token of the market
    function deploy(
        address oracleProvider,
        address settlementToken,
        string memory lpTokenUri
    ) internal returns (address market) {
        parameters = Parameters({
            oracleProvider: oracleProvider,
            settlementToken: settlementToken,
            lpTokenUri: lpTokenUri
        });
        market = address(
            new USUMMarket{
                salt: keccak256(
                    abi.encode(
                        oracleProvider,
                        settlementToken
                    )
                )
            }()
        );
        delete parameters;
    }
}
