// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IAutomate, IOpsProxyFactory} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {ChromaticMarketFactory} from "@chromatic-protocol/contracts/core/ChromaticMarketFactory.sol";
import {KeeperFeePayerMock} from "@chromatic-protocol/contracts/mocks/KeeperFeePayerMock.sol";
import {OracleProviderMock} from "@chromatic-protocol/contracts/mocks/OracleProviderMock.sol";
import {Token} from "@chromatic-protocol/contracts/mocks/Token.sol";
import {ChromaticLiquidatorMock} from "@chromatic-protocol/contracts/mocks/ChromaticLiquidatorMock.sol";
import {ChromaticVaultMock} from "@chromatic-protocol/contracts/mocks/ChromaticVaultMock.sol";

abstract contract BaseSetup is Test {
    KeeperFeePayerMock keeperFeePayer;
    OracleProviderMock oracleProvider;
    Token usdc;
    ChromaticMarketFactory factory;
    ChromaticVaultMock vault;
    ChromaticLiquidatorMock liquidator;
    IChromaticMarket market;
    ICLBToken clbToken;

    function setUp() public virtual {
        IAutomate _automate = IAutomate(address(5555));
        IOpsProxyFactory _opf = IOpsProxyFactory(address(6666));
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.gelato.selector),
            abi.encode(address(_automate))
        );
        vm.mockCall(
            address(_opf),
            abi.encodeWithSelector(_opf.getProxyOf.selector),
            abi.encode(address(this), true)
        );

        oracleProvider = new OracleProviderMock();

        usdc = new Token("USDC", "USDC");
        usdc.faucet(1000000 ether);

        factory = new ChromaticMarketFactory();

        keeperFeePayer = new KeeperFeePayerMock(factory);
        factory.setKeeperFeePayer(address(keeperFeePayer));

        vault = new ChromaticVaultMock(factory, address(_automate), address(_opf));
        factory.setVault(address(vault));

        liquidator = new ChromaticLiquidatorMock(factory, address(_automate), address(_opf));
        factory.setLiquidator(address(liquidator));

        factory.registerOracleProvider(address(oracleProvider));
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
    }
}
