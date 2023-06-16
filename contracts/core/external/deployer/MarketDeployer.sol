// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {ChromaticMarket} from "@chromatic-protocol/contracts/core/ChromaticMarket.sol";

/**
 * @title MarketDeployer
 * @notice Storage struct for deploying a ChromaticMarket contract
 */
struct MarketDeployer {
    Parameters parameters;
}

/**
 * @title Parameters
 * @notice Struct for storing deployment parameters
 */
struct Parameters {
    address oracleProvider;
    address settlementToken;
}

/**
 * @title MarketDeployerLib
 * @notice Library for deploying a ChromaticMarket contract
 */
library MarketDeployerLib {
    /**
     * @notice Deploys a ChromaticMarket contract
     * @param self The MarketDeployer storage
     * @param oracleProvider The address of the oracle provider
     * @param settlementToken The address of the settlement token
     * @return market The address of the deployed ChromaticMarket contract
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
            new ChromaticMarket{salt: keccak256(abi.encode(oracleProvider, settlementToken))}()
        );
        delete self.parameters;
    }
}
