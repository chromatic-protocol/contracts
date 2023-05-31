// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {USUMMarket} from "@usum/core/USUMMarket.sol";

struct MarketDeployer {
    Parameters parameters;
}

struct Parameters {
    address oracleProvider;
    address settlementToken;
}

/**
 * @title MarketDeployer
 * @notice This library provides a function to deploy a USUMMarket contract.
 */
library MarketDeployerLib {
    /**
     * @notice Deploys a USUMMarket contract.
     * @param self The MarketDeployer storage.
     * @param oracleProvider The address of the oracle provider.
     * @param settlementToken The address of the settlement token.
     * @return market The address of the deployed USUMMarket contract.
     */
    function deploy(
        MarketDeployer storage self,
        address oracleProvider,
        address settlementToken
    ) external returns (address market) {
        self.parameters = Parameters({
            oracleProvider: oracleProvider,
            settlementToken: settlementToken
        });
        market = address(
            new USUMMarket{salt: keccak256(abi.encode(oracleProvider, settlementToken))}()
        );
        delete self.parameters;
    }
}
