// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
import {CLBTokenDeployerLib} from "@chromatic-protocol/contracts/core/libraries/deployer/CLBTokenDeployer.sol";
import {MarketStorage, MarketStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {Diamond} from "@chromatic-protocol/contracts/core/base/Diamond.sol";

/**
 * @title ChromaticMarket
 * @dev A contract that represents a Chromatic market, combining trade and liquidity functionalities.
 */
contract ChromaticMarket is Diamond {
    constructor(address diamondCutFacet) Diamond(diamondCutFacet) {
        IChromaticMarketFactory factory = IChromaticMarketFactory(msg.sender);

        (address _oracleProvider, address _settlementToken) = factory.parameters();
        MarketStorage storage ms = MarketStorageLib.marketStorage();

        ms.factory = factory;
        ms.oracleProvider = IOracleProvider(_oracleProvider);
        ms.settlementToken = IERC20Metadata(_settlementToken);
        ms.clbToken = ICLBToken(CLBTokenDeployerLib.deploy());
        ms.liquidator = ILiquidator(factory.liquidator());
        ms.vault = IChromaticVault(factory.vault());
        ms.keeperFeePayer = IKeeperFeePayer(factory.keeperFeePayer());

        ms.liquidityPool.initialize();
    }
}
