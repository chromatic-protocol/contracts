// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IAutomate, IGelato, IProxyModule, IOpsProxyFactory} from "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import {IWETH9} from "@chromatic-protocol/contracts/core/interfaces/IWETH9.sol";
import {IOracleProviderRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/IOracleProviderRegistry.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IVaultEarningDistributor} from "@chromatic-protocol/contracts/core/interfaces/IVaultEarningDistributor.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {OracleProviderProperties} from "@chromatic-protocol/contracts/core/libraries/registry/OracleProviderProperties.sol";
import {ChromaticMarketFactory} from "@chromatic-protocol/contracts/core/ChromaticMarketFactory.sol";
import {KeeperFeePayer} from "@chromatic-protocol/contracts/core/KeeperFeePayer.sol";
import {FixedPriceSwapRouter} from "@chromatic-protocol/contracts/mocks/FixedPriceSwapRouter.sol";
import {OracleProviderMock} from "@chromatic-protocol/contracts/mocks/OracleProviderMock.sol";
import {TestSettlementToken} from "@chromatic-protocol/contracts/mocks/TestSettlementToken.sol";
import {GelatoLiquidatorMock} from "@chromatic-protocol/contracts/mocks/GelatoLiquidatorMock.sol";
import {ChromaticVaultMock} from "@chromatic-protocol/contracts/mocks/ChromaticVaultMock.sol";
import {DiamondLoupeFacet} from "@chromatic-protocol/contracts/core/facets/DiamondLoupeFacet.sol";
import {MarketDiamondCutFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketDiamondCutFacet.sol";
import {MarketStateFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketStateFacet.sol";
import {MarketLiquidityFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacet.sol";
import {MarketLensFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLensFacet.sol";
import {MarketTradeOpenPositionFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeOpenPositionFacet.sol";
import {MarketTradeClosePositionFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeClosePositionFacet.sol";
import {MarketLiquidateFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidateFacet.sol";
import {MarketSettleFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketSettleFacet.sol";
import {ChromaticRouter} from "@chromatic-protocol/contracts/periphery/ChromaticRouter.sol";

contract WETH is IWETH9, ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function deposit() external payable override {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external override {
        _burn(msg.sender, amount);
        (bool sent, bytes memory data) = msg.sender.call{value: amount}("");
    }
}

abstract contract BaseSetup is Test {
    FixedPriceSwapRouter swapRouter;
    KeeperFeePayer keeperFeePayer;
    OracleProviderMock oracleProvider;
    TestSettlementToken ctst;
    ChromaticMarketFactory factory;
    ChromaticVaultMock vault;
    GelatoLiquidatorMock liquidator;
    IChromaticMarket market;
    ICLBToken clbToken;
    ChromaticRouter router;

    IWETH9 weth;
    IAutomate automate;

    function setUp() public virtual {
        IAutomate _automate = IAutomate(address(5555));
        automate = _automate;

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
            abi.encodeWithSelector(IGelato(address(_automate)).feeCollector.selector),
            abi.encode(address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.taskModuleAddresses.selector),
            abi.encode(address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(IProxyModule(address(_automate)).opsProxyFactory.selector),
            abi.encode(address(_automate))
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(IOpsProxyFactory(address(_automate)).getProxyOf.selector),
            abi.encode(address(_automate), true)
        );
        vm.mockCall(
            address(_automate),
            abi.encodeWithSelector(_automate.createTask.selector),
            abi.encode(bytes32(""))
        );

        oracleProvider = new OracleProviderMock();
        oracleProvider.increaseVersion(1 ether);

        weth = new WETH("Wrapped Ether", "wETH");
        swapRouter = new FixedPriceSwapRouter(weth);
        weth.deposit{value: 1000000 ether}();
        weth.transfer(address(swapRouter), 1000000 ether);

        ctst = new TestSettlementToken("cTST", "cTST", 1000000 ether, 86400);
        ctst.faucet();
        swapRouter.setEthPriceInToken(address(ctst), 1 ether);

        factory = new ChromaticMarketFactory(
            address(new MarketDiamondCutFacet()),
            address(new DiamondLoupeFacet()),
            address(new MarketStateFacet()),
            address(new MarketLiquidityFacet()),
            address(new MarketLensFacet()),
            address(new MarketTradeOpenPositionFacet()),
            address(new MarketTradeClosePositionFacet()),
            address(new MarketLiquidateFacet()),
            address(new MarketSettleFacet())
        );

        keeperFeePayer = new KeeperFeePayer(factory, swapRouter, weth);
        swapRouter.addWhitelistedClient(address(keeperFeePayer));
        factory.updateKeeperFeePayer(address(keeperFeePayer));

        vault = new ChromaticVaultMock(factory, IVaultEarningDistributor(address(this)));
        factory.setVault(address(vault));

        liquidator = new GelatoLiquidatorMock(factory, address(_automate));
        factory.updateLiquidator(address(liquidator));

        factory.registerOracleProvider(
            address(oracleProvider),
            OracleProviderProperties({
                minTakeProfitBPS: 1000, // 10%
                maxTakeProfitBPS: 100000, // 1000%
                leverageLevel: 0
            })
        );
        factory.registerSettlementToken(
            address(ctst),
            address(oracleProvider), // oracleProvider
            1 ether, // minimumMargin
            1000, // interestRate, 10%
            500, // flashLoanFeeRate, 5%
            10 ether, // earningDistributionThreshold, $10
            3000 // uniswapFeeRate, 0.3%
        );

        factory.createMarket(address(oracleProvider), address(ctst));
        market = IChromaticMarket(factory.getMarkets()[0]);
        clbToken = market.clbToken();
        router = new ChromaticRouter(address(factory));
    }
}
