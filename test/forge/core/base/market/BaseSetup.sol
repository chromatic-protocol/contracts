// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IAutomate, IOpsProxyFactory} from "@usum/core/base/gelato/Types.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {USUMMarketFactory} from "@usum/core/USUMMarketFactory.sol";
import {KeeperFeePayerMock} from "@usum/mocks/KeeperFeePayerMock.sol";
import {OracleProviderMock} from "@usum/mocks/OracleProviderMock.sol";
import {Token} from "@usum/mocks/Token.sol";
import {USUMLiquidatorMock} from "@usum/mocks/USUMLiquidatorMock.sol";
import {USUMVaultMock} from "@usum/mocks/USUMVaultMock.sol";

abstract contract BaseSetup is Test {
    KeeperFeePayerMock keeperFeePayer;
    OracleProviderMock oracleProvider;
    Token usdc;
    USUMMarketFactory factory;
    USUMVaultMock vault;
    USUMLiquidatorMock liquidator;
    IUSUMMarket market;

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

        factory = new USUMMarketFactory();

        keeperFeePayer = new KeeperFeePayerMock(factory);
        factory.setKeeperFeePayer(address(keeperFeePayer));

        vault = new USUMVaultMock(factory, address(_automate), address(_opf));
        factory.setVault(address(vault));

        liquidator = new USUMLiquidatorMock(
            factory,
            address(_automate),
            address(_opf)
        );
        factory.setLiquidator(address(liquidator));

        factory.registerOracleProvider(address(oracleProvider));
        factory.registerSettlementToken(
            address(usdc),
            1 ether, // minimumTakerMargin
            1000, // interestRate, 10%
            500, // flashLoanFeeRate, 5%
            10 ether, // earningDistributionThreshold, $10
            3000 // uniswapFeeRate, 0.3%
        );

        factory.createMarket(address(oracleProvider), address(usdc));
        market = IUSUMMarket(factory.getMarkets()[0]);
    }
}
