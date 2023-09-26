// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IAutomate, IOpsProxyFactory} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {IOracleProviderRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/IOracleProviderRegistry.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IVaultEarningDistributor} from "@chromatic-protocol/contracts/core/interfaces/IVaultEarningDistributor.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {ChromaticMarketFactory} from "@chromatic-protocol/contracts/core/ChromaticMarketFactory.sol";
import {KeeperFeePayerMock} from "@chromatic-protocol/contracts/mocks/KeeperFeePayerMock.sol";
import {OracleProviderMock} from "@chromatic-protocol/contracts/mocks/OracleProviderMock.sol";
import {Token} from "@chromatic-protocol/contracts/mocks/Token.sol";
import {GelatoLiquidatorMock} from "@chromatic-protocol/contracts/mocks/GelatoLiquidatorMock.sol";
import {ChromaticVaultMock} from "@chromatic-protocol/contracts/mocks/ChromaticVaultMock.sol";
import {DiamondLoupeFacet} from "@chromatic-protocol/contracts/core/facets/DiamondLoupeFacet.sol";
import {MarketDiamondCutFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketDiamondCutFacet.sol";
import {MarketStateFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketStateFacet.sol";
import {MarketLiquidityFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacet.sol";
import {MarketLensFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLensFacet.sol";
import {MarketTradeFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeFacet.sol";
import {MarketLiquidateFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidateFacet.sol";
import {MarketSettleFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketSettleFacet.sol";
import {ChromaticRouter} from "@chromatic-protocol/contracts/periphery/ChromaticRouter.sol";

abstract contract BaseSetup is Test {
    KeeperFeePayerMock keeperFeePayer;
    OracleProviderMock oracleProvider;
    Token usdc;
    ChromaticMarketFactory factory;
    ChromaticVaultMock vault;
    GelatoLiquidatorMock liquidator;
    IChromaticMarket market;
    ICLBToken clbToken;
    ChromaticRouter router;

    IAutomate automate;
    IOpsProxyFactory opf;

    function setUp() public virtual {
        IAutomate _automate = IAutomate(address(5555));
        IOpsProxyFactory _opf = IOpsProxyFactory(address(6666));
        automate = _automate;
        opf = _opf;

        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.getFeeDetails.selector),
            abi.encode(0, address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.gelato.selector),
            abi.encode(address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.createTask.selector),
            abi.encode(bytes32(""))
        );
        vm.mockCall(
            address(_opf),
            abi.encodeWithSelector(_opf.getProxyOf.selector),
            abi.encode(address(this), true)
        );

        oracleProvider = new OracleProviderMock();
        oracleProvider.increaseVersion(1 ether);

        usdc = new Token("USDC", "USDC");
        usdc.faucet(1000000 ether);

        factory = new ChromaticMarketFactory(
            address(new MarketDiamondCutFacet()),
            address(new DiamondLoupeFacet()),
            address(new MarketStateFacet()),
            address(new MarketLiquidityFacet()),
            address(new MarketLensFacet()),
            address(new MarketTradeFacet()),
            address(new MarketLiquidateFacet()),
            address(new MarketSettleFacet())
        );

        keeperFeePayer = new KeeperFeePayerMock(factory);
        factory.setKeeperFeePayer(address(keeperFeePayer));

        vault = new ChromaticVaultMock(factory, IVaultEarningDistributor(address(this)));
        factory.setVault(address(vault));

        liquidator = new GelatoLiquidatorMock(factory, address(_automate), address(_opf));
        factory.setLiquidator(address(liquidator));

        factory.registerOracleProvider(
            address(oracleProvider),
            IOracleProviderRegistry.OracleProviderProperties({
                minTakeProfitBPS: 1000, // 10%
                maxTakeProfitBPS: 100000, // 1000%
                leverageLevel: 0
            })
        );
        factory.registerSettlementToken(
            address(usdc),
            1 ether, // minimumMargin
            1000, // interestRate, 10%
            500, // flashLoanFeeRate, 5%
            10 ether, // earningDistributionThreshold, $10
            3000 // uniswapFeeRate, 0.3%
        );

        factory.createMarket(address(oracleProvider), address(usdc));
        market = IChromaticMarket(factory.getMarkets()[0]);
        clbToken = market.clbToken();
        router = new ChromaticRouter(address(factory));
    }
}
