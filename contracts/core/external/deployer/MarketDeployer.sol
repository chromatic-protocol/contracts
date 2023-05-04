// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {USUMMarket} from "@usum/core/USUMMarket.sol";

struct MarketDeployer {
    Parameters parameters;
}

struct Parameters {
    address oracleProvider;
    address settlementToken;
}

library MarketDeployerLib {

    // do not move
    // to generate abi and typechain-types
    event MarketDeployed(
        address oracleProvider,
        address settlementToken,
        address market
    );

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
            new USUMMarket{
                salt: keccak256(abi.encode(oracleProvider, settlementToken))
            }()
        );
        emit MarketDeployed(oracleProvider, settlementToken, market);
        delete self.parameters;
    }
}
