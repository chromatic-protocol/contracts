// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {ChromaticMarketFactory} from "@chromatic-protocol/contracts/core/ChromaticMarketFactory.sol"; // Core contract
import {ChromaticMarket} from "@chromatic-protocol/contracts/core/ChromaticMarket.sol"; // Core contract
import {ChromaticVault} from "@chromatic-protocol/contracts/core/ChromaticVault.sol"; // Core contract
import {CLBToken} from "@chromatic-protocol/contracts/core/CLBToken.sol"; // Core contract
import {KeeperFeePayer} from "@chromatic-protocol/contracts/core/KeeperFeePayer.sol"; // Core contract
import {Diamond} from "@chromatic-protocol/contracts/core/base/Diamond.sol"; // ChromaticMarket is a Diamond
import {DiamondCutFacetBase} from "@chromatic-protocol/contracts/core/facets/DiamondCutFacetBase.sol"; // MarketDiamondCutFacet is DiamondCutFacetBase
import {DiamondLoupeFacet} from "@chromatic-protocol/contracts/core/facets/DiamondLoupeFacet.sol"; // Core contract
import {MarketDiamondCutFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketDiamondCutFacet.sol"; // Core contract
import {MarketLensFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLensFacet.sol"; // Core contract
import {MarketLiquidityFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidityFacetBase.sol"; // Core contract
import {MarketSettleFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketSettleFacet.sol"; // Core contract
import {MarketTradeFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeFacetBase.sol"; // MarketTradeFacet is MarketTradeFacetBase
import {MarketFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketFacetBase.sol"; // MarketLiquidityFacet is MarketFacetBase
import {MarketLiquidateFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketLiquidateFacet.sol"; // Core contract
import {MarketAddLiquidityFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketAddLiquidityFacet.sol"; // Core contract
import {MarketRemoveLiquidityFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketRemoveLiquidityFacet.sol"; // Core contract
import {MarketStateFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketStateFacet.sol"; // Core contract
import {MarketTradeOpenPositionFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeOpenPositionFacet.sol"; // Core contract
import {MarketTradeClosePositionFacet} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeClosePositionFacet.sol"; // Core contract
import {GelatoLiquidator} from "@chromatic-protocol/contracts/core/automation/GelatoLiquidator.sol"; // Core contract
import {GelatoVaultEarningDistributor} from "@chromatic-protocol/contracts/core/automation/GelatoVaultEarningDistributor.sol"; // Core contract
import {LiquidatorBase} from "@chromatic-protocol/contracts/core/automation/LiquidatorBase.sol"; // GelatoLiquidator is LiquidatorBase
import {VaultEarningDistributorBase} from "@chromatic-protocol/contracts/core/automation/VaultEarningDistributorBase.sol"; // GelatoVaultEarningDistributor is VaultEarningDistributorBase
import {BinMargin} from "@chromatic-protocol/contracts/core/libraries/BinMargin.sol";
import "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {DiamondStorage} from "@chromatic-protocol/contracts/core/libraries/DiamondStorage.sol";
import {InterestRate} from "@chromatic-protocol/contracts/core/libraries/InterestRate.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {MarketStorage} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {PositionUtil} from "@chromatic-protocol/contracts/core/libraries/PositionUtil.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {Errors} from "@chromatic-protocol/contracts/core/libraries/Errors.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {CLBTokenDeployerLib} from "@chromatic-protocol/contracts/core/libraries/deployer/CLBTokenDeployer.sol";
import {MarketDeployer} from "@chromatic-protocol/contracts/core/libraries/deployer/MarketDeployer.sol";
import {AccruedInterest} from "@chromatic-protocol/contracts/core/libraries/liquidity/AccruedInterest.sol";
import {BinClosedPosition} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinClosedPosition.sol";
import {BinClosingPosition} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinClosingPosition.sol";
import {BinLiquidity} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinLiquidity.sol";
import {BinPendingPosition} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinPendingPosition.sol";
import {BinPosition} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinPosition.sol";
import {LiquidityBin} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityBin.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {PositionParam} from "@chromatic-protocol/contracts/core/libraries/liquidity/PositionParam.sol";
import {OracleProviderProperties} from "@chromatic-protocol/contracts/core/libraries/registry/OracleProviderProperties.sol";
import {OracleProviderRegistry} from "@chromatic-protocol/contracts/core/libraries/registry/OracleProviderRegistry.sol";
import {SettlementTokenRegistry} from "@chromatic-protocol/contracts/core/libraries/registry/SettlementTokenRegistry.sol"; // x
import {SupraFeedOracle} from "@chromatic-protocol/contracts/oracle/SupraFeedOracle.sol";
import {PythFeedOracle} from "@chromatic-protocol/contracts/oracle/PythFeedOracle.sol";
import {ChainlinkFeedOracle} from "@chromatic-protocol/contracts/oracle/ChainlinkFeedOracle.sol"; // x
import {SupraSValueFeed} from "@chromatic-protocol/contracts/oracle/types/SupraSValueFeed.sol";
import {ChainlinkRound} from "@chromatic-protocol/contracts/oracle/types/ChainlinkRound.sol";
import {ChainlinkAggregator} from "@chromatic-protocol/contracts/oracle/types/ChainlinkAggregator.sol";
import {ChromaticRouter} from "@chromatic-protocol/contracts/periphery/ChromaticRouter.sol"; // x
import {ChromaticLens} from "@chromatic-protocol/contracts/periphery/ChromaticLens.sol"; // x
import {ChromaticAccount} from "@chromatic-protocol/contracts/periphery/ChromaticAccount.sol";
import {VerifyCallback} from "@chromatic-protocol/contracts/periphery/base/VerifyCallback.sol";
import {AccountFactory} from "@chromatic-protocol/contracts/periphery/base/AccountFactory.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IVaultEarningDistributor} from "@chromatic-protocol/contracts/core/interfaces/IVaultEarningDistributor.sol";
import {IChromaticRouter} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticRouter.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IWETH9} from "@chromatic-protocol/contracts/core/interfaces/IWETH9.sol";
import "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";
import "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {PriceFeedMock} from "@chromatic-protocol/contracts/mocks/PriceFeedMock.sol"; // x
import {TestSettlementToken} from "@chromatic-protocol/contracts/mocks/TestSettlementToken.sol"; // x
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {MockFlashloan} from "./MockFlashloan.sol";
import {MockCallBack} from "./MockCallBack.sol";
import {MockRouter} from "./MockRouter.sol";
import {MockERC777} from "./MockERC777.sol";
import {MockChromaticAccount} from "./MockChromaticAccount.sol";
import {MockChromaticAccountV2} from "./MockChromaticAccountV2.sol";
import {MockChromaticAccountV3} from "./MockChromaticAccountV3.sol";
import {MockFlashloanV2} from "./MockFlashloanV2.sol";

/** 
Run this test with:
forge test -vvvvv --match-contract Deploy --match-test test_setUp
*/

contract Deploy is Test {
    using Strings for *;

    string public ARB_RPC_URL =
        "https://arb-mainnet.g.alchemy.com/v2/dc67PtVCdrbbiu40eIihsiS9w1oOnLKO";
    uint256 public ARB_FORK_ID;

    // Facets: ChromaticMarketFactory
    MarketDiamondCutFacet public contract_MarketDiamondCutFacet;
    DiamondLoupeFacet public contract_DiamondLoupeFacet;
    MarketStateFacet public contract_MarketStateFacet;
    MarketAddLiquidityFacet public contract_MarketAddLiquidityFacet;
    MarketRemoveLiquidityFacet public contract_MarketRemoveLiquidityFacet;
    MarketLensFacet public contract_MarketLensFacet;
    MarketTradeOpenPositionFacet public contract_MarketTradeOpenPositionFacet;
    MarketTradeClosePositionFacet public contract_MarketTradeClosePositionFacet;
    MarketLiquidateFacet public contract_MarketLiquidateFacet;
    MarketSettleFacet public contract_MarketSettleFacet;

    // Core
    ChromaticMarketFactory public contract_ChromaticMarketFactory;
    ChromaticVault public contract_ChromaticVault;
    GelatoVaultEarningDistributor public contract_GelatoVaultEarningDistributor;
    ChromaticRouter public contract_ChromaticRouter;
    ChromaticLens public contract_ChromaticLens;
    KeeperFeePayer public contract_KeeperFeePayer;
    GelatoLiquidator public contract_GelatoLiquidator;
    PriceFeedMock public contract_PriceFeedMock;
    ChainlinkFeedOracle public contract_ChainlinkFeedOracle;
    TestSettlementToken public contract_TestSettlementToken;
    MockERC777 public contract_MockERC777;
    ChromaticMarket public contract_ChromaticMarket;
    CLBToken public contract_CLBToken;

    // Users
    IAutomate public _automate = IAutomate(address(5555));
    address public owner = vm.addr(100);
    address public user1 = vm.addr(101);
    address public user2 = vm.addr(102);
    address public user3 = vm.addr(103);
    address public user4 = vm.addr(104);
    address public user5 = vm.addr(105);

    // Tokens
    IERC20 public contract_WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

    // Misc
    address public constant UNISWAPV3 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    function setUp() public virtual {
        _deployAll();
        // _deployAllWithMockERC777();
    }

    function test_setUp() public view {
        console.log(StdStyle.yellow("\n\ntest_setUp()"));
        console.log(StdStyle.yellow("__________________________\n"));
        console.log(
            "contract_MarketDiamondCutFacet -> %s",
            address(contract_MarketDiamondCutFacet)
        );
        console.log("contract_DiamondLoupeFacet -> %s", address(contract_DiamondLoupeFacet));
        console.log("contract_MarketStateFacet -> %s", address(contract_MarketStateFacet));
        console.log("contract_MarketAddLiquidityFacet -> %s", address(contract_MarketAddLiquidityFacet));
        console.log("contract_MarketRemoveLiquidityFacet -> %s", address(contract_MarketRemoveLiquidityFacet));
        console.log("contract_MarketLensFacet -> %s", address(contract_MarketLensFacet));
        console.log(
            "contract_MarketTradeOpenPositionFacet -> %s",
            address(contract_MarketTradeOpenPositionFacet)
        );
        console.log(
            "contract_MarketTradeClosePositionFacet -> %s",
            address(contract_MarketTradeClosePositionFacet)
        );
        console.log("contract_MarketLiquidateFacet -> %s", address(contract_MarketLiquidateFacet));
        console.log("contract_MarketSettleFacet -> %s", address(contract_MarketSettleFacet));
        console.log(
            "contract_ChromaticMarketFactory -> %s",
            address(contract_ChromaticMarketFactory)
        );
        console.log("contract_ChromaticVault -> %s", address(contract_ChromaticVault));
        console.log(
            "contract_GelatoVaultEarningDistributor -> %s",
            address(contract_GelatoVaultEarningDistributor)
        );
        console.log("contract_ChromaticRouter -> %s", address(contract_ChromaticRouter));
        console.log("contract_ChromaticLens -> %s", address(contract_ChromaticLens));
        console.log("contract_KeeperFeePayer -> %s", address(contract_KeeperFeePayer));
        console.log("contract_GelatoLiquidator -> %s", address(contract_GelatoLiquidator));
        console.log("contract_PriceFeedMock -> %s", address(contract_PriceFeedMock));
        console.log("contract_ChainlinkFeedOracle -> %s", address(contract_ChainlinkFeedOracle));
        console.log("contract_TestSettlementToken -> %s", address(contract_TestSettlementToken));
        console.log("contract_ChromaticMarket -> %s", address(contract_ChromaticMarket));
        console.log("contract_CLBToken -> %s", address(contract_CLBToken));
        // Users
        console.log("_automate -> %s", address(_automate));
        console.log("owner -> %s", address(owner));
        console.log("user1 -> %s", address(user1));
        console.log("user2 -> %s", address(user2));
        console.log("user3 -> %s", address(user3));
        console.log("user4 -> %s", address(user4));
        console.log("user5 -> %s", address(user5));
    }

    function _deployAll() internal {
        console.log("_deployAll");

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

        vm.startPrank(owner, owner);
        contract_MarketDiamondCutFacet = new MarketDiamondCutFacet();
        contract_DiamondLoupeFacet = new DiamondLoupeFacet();
        contract_MarketStateFacet = new MarketStateFacet();
        contract_MarketAddLiquidityFacet = new MarketAddLiquidityFacet();
        contract_MarketRemoveLiquidityFacet = new MarketRemoveLiquidityFacet();
        contract_MarketLensFacet = new MarketLensFacet();
        contract_MarketTradeOpenPositionFacet = new MarketTradeOpenPositionFacet();
        contract_MarketTradeClosePositionFacet = new MarketTradeClosePositionFacet();
        contract_MarketLiquidateFacet = new MarketLiquidateFacet();
        contract_MarketSettleFacet = new MarketSettleFacet();

        /**
            ChromaticMarketFactory:
            constructor(
                address _marketDiamondCutFacet,
                address _marketLoupeFacet,
                address _marketStateFacet,
                address _marketLiquidityFacet,
                address _marketLiquidityLensFacet,
                address _marketTradeFacet,
                address _marketLiquidateFacet,
                address _marketSettleFacet
            ) 
        */
        contract_ChromaticMarketFactory = new ChromaticMarketFactory(
            address(contract_MarketDiamondCutFacet),
            address(contract_DiamondLoupeFacet),
            address(contract_MarketStateFacet),
            address(contract_MarketAddLiquidityFacet),
            address(contract_MarketRemoveLiquidityFacet),
            address(contract_MarketLensFacet),
            address(contract_MarketTradeOpenPositionFacet),
            address(contract_MarketTradeClosePositionFacet),
            address(contract_MarketLiquidateFacet),
            address(contract_MarketSettleFacet)
        );

        /**
            GelatoVaultEarningDistributor:
            constructor(
                IChromaticMarketFactory _factory,
                address _automate
            ) 
        */
        contract_GelatoVaultEarningDistributor = new GelatoVaultEarningDistributor(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            address(_automate)
        );

        /**
            ChromaticVault:
            constructor(IChromaticMarketFactory _factory, IVaultEarningDistributor _earningDistributor)
        */
        contract_ChromaticVault = new ChromaticVault(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            IVaultEarningDistributor(address(contract_GelatoVaultEarningDistributor))
        );

        /**
            ChromaticRouter:
            constructor(address _marketFactory) AccountFactory(_marketFactory) 
        */
        contract_ChromaticRouter = new ChromaticRouter(address(contract_ChromaticMarketFactory));

        /**
            ChromaticLens:
            constructor(IChromaticRouter _router)
        */
        contract_ChromaticLens = new ChromaticLens(
            IChromaticRouter(address(contract_ChromaticRouter))
        );

        /**
            KeeperFeePayer:
            constructor(IChromaticMarketFactory _factory, ISwapRouter _uniswapRouter, IWETH9 _weth)
        */
        contract_KeeperFeePayer = new KeeperFeePayer(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            ISwapRouter(UNISWAPV3),
            IWETH9(address(contract_WETH))
        );

        contract_ChromaticMarketFactory.updateKeeperFeePayer(address(contract_KeeperFeePayer));
        contract_ChromaticMarketFactory.setVault(address(contract_ChromaticVault));

        /**
            GelatoLiquidator:
            constructor(
                IChromaticMarketFactory _factory,
                address _automate
            ) LiquidatorBase(_factory) AutomateReady(_automate, address(this)) 
        */
        contract_GelatoLiquidator = new GelatoLiquidator(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            address(_automate)
        );
        contract_ChromaticMarketFactory.updateLiquidator(address(contract_GelatoLiquidator));

        /**
            PriceFeedMock:
            constructor()
        */
        contract_PriceFeedMock = new PriceFeedMock();
        contract_PriceFeedMock.setRoundData(1e18);

        /**
            ChainlinkFeedOracle:
            constructor(ChainlinkAggregator aggregator_)
        */
        contract_ChainlinkFeedOracle = new ChainlinkFeedOracle(
            ChainlinkAggregator.wrap(address(contract_PriceFeedMock))
        );

        contract_ChromaticMarketFactory.registerOracleProvider(
            address(address(contract_ChainlinkFeedOracle)),
            OracleProviderProperties({
                minTakeProfitBPS: 1000, // 10%
                maxTakeProfitBPS: 100000, // 1000%
                leverageLevel: 0
            })
        );

        /**
            TestSettlementToken:
            constructor(
                string memory name_,
                string memory symbol_,
                uint256 faucetAmount_,
                uint256 faucetMinInterval_
            ) ERC20("", "")
        */
        contract_TestSettlementToken = new TestSettlementToken("", "", 1000000e18, 86400);

        contract_ChromaticMarketFactory.registerSettlementToken(
            address(contract_TestSettlementToken),
            address(contract_ChainlinkFeedOracle), // oracleProvider
            1 ether, // minimumMargin
            1000, // interestRate, 10%
            500, // flashLoanFeeRate, 5%
            10 ether, // earningDistributionThreshold, $10
            3000 // uniswapFeeRate, 0.3%
        );

        contract_ChromaticMarketFactory.createMarket(
            address(contract_ChainlinkFeedOracle),
            address(contract_TestSettlementToken)
        );
        contract_ChromaticMarket = ChromaticMarket(
            payable(contract_ChromaticMarketFactory.getMarkets()[0])
        );
        contract_CLBToken = CLBToken(
            address(IChromaticMarket(address(contract_ChromaticMarket)).clbToken())
        );

        contract_PriceFeedMock.setRoundData(1e18);
        vm.stopPrank();
    }

    function _deployAllWithMockERC777() internal {
        // UNCOMMENT TO ENABLE FORKING V
        ARB_FORK_ID = vm.createFork(ARB_RPC_URL, 173394920); // 23/01/2024 16:17
        vm.selectFork(ARB_FORK_ID);
        // UNCOMMENT TO ENABLE FORKING ^

        console.log("_deployAllWithMockERC777");

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

        vm.startPrank(owner, owner);
        contract_MarketDiamondCutFacet = new MarketDiamondCutFacet();
        contract_DiamondLoupeFacet = new DiamondLoupeFacet();
        contract_MarketStateFacet = new MarketStateFacet();
        contract_MarketAddLiquidityFacet = new MarketAddLiquidityFacet();
        contract_MarketRemoveLiquidityFacet = new MarketRemoveLiquidityFacet();
        contract_MarketLensFacet = new MarketLensFacet();
        contract_MarketTradeOpenPositionFacet = new MarketTradeOpenPositionFacet();
        contract_MarketTradeClosePositionFacet = new MarketTradeClosePositionFacet();
        contract_MarketLiquidateFacet = new MarketLiquidateFacet();
        contract_MarketSettleFacet = new MarketSettleFacet();

        /**
            ChromaticMarketFactory:
            constructor(
                address _marketDiamondCutFacet,
                address _marketLoupeFacet,
                address _marketStateFacet,
                address _marketLiquidityFacet,
                address _marketLiquidityLensFacet,
                address _marketTradeFacet,
                address _marketLiquidateFacet,
                address _marketSettleFacet
            ) 
        */
        contract_ChromaticMarketFactory = new ChromaticMarketFactory(
            address(contract_MarketDiamondCutFacet),
            address(contract_DiamondLoupeFacet),
            address(contract_MarketStateFacet),
            address(contract_MarketAddLiquidityFacet),
            address(contract_MarketRemoveLiquidityFacet),
            address(contract_MarketLensFacet),
            address(contract_MarketTradeOpenPositionFacet),
            address(contract_MarketTradeClosePositionFacet),
            address(contract_MarketLiquidateFacet),
            address(contract_MarketSettleFacet)
        );

        /**
            GelatoVaultEarningDistributor:
            constructor(
                IChromaticMarketFactory _factory,
                address _automate
            ) 
        */
        contract_GelatoVaultEarningDistributor = new GelatoVaultEarningDistributor(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            address(_automate)
        );

        /**
            ChromaticVault:
            constructor(IChromaticMarketFactory _factory, IVaultEarningDistributor _earningDistributor)
        */
        contract_ChromaticVault = new ChromaticVault(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            IVaultEarningDistributor(address(contract_GelatoVaultEarningDistributor))
        );

        /**
            ChromaticRouter:
            constructor(address _marketFactory) AccountFactory(_marketFactory) 
        */
        contract_ChromaticRouter = new ChromaticRouter(address(contract_ChromaticMarketFactory));

        /**
            ChromaticLens:
            constructor(IChromaticRouter _router)
        */
        contract_ChromaticLens = new ChromaticLens(
            IChromaticRouter(address(contract_ChromaticRouter))
        );

        /**
            KeeperFeePayer:
            constructor(IChromaticMarketFactory _factory, ISwapRouter _uniswapRouter, IWETH9 _weth)
        */
        contract_KeeperFeePayer = new KeeperFeePayer(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            ISwapRouter(UNISWAPV3),
            IWETH9(address(contract_WETH))
        );

        contract_ChromaticMarketFactory.updateKeeperFeePayer(address(contract_KeeperFeePayer));
        contract_ChromaticMarketFactory.setVault(address(contract_ChromaticVault));

        /**
            GelatoLiquidator:
            constructor(
                IChromaticMarketFactory _factory,
                address _automate
            ) LiquidatorBase(_factory) AutomateReady(_automate, address(this)) 
        */
        contract_GelatoLiquidator = new GelatoLiquidator(
            IChromaticMarketFactory(address(contract_ChromaticMarketFactory)),
            address(_automate)
        );
        contract_ChromaticMarketFactory.updateLiquidator(address(contract_GelatoLiquidator));

        /**
            PriceFeedMock:
            constructor()
        */
        contract_PriceFeedMock = new PriceFeedMock();
        contract_PriceFeedMock.setRoundData(1e18);

        /**
            ChainlinkFeedOracle:
            constructor(ChainlinkAggregator aggregator_)
        */
        contract_ChainlinkFeedOracle = new ChainlinkFeedOracle(
            ChainlinkAggregator.wrap(address(contract_PriceFeedMock))
        );

        contract_ChromaticMarketFactory.registerOracleProvider(
            address(address(contract_ChainlinkFeedOracle)),
            OracleProviderProperties({
                minTakeProfitBPS: 1000, // 10%
                maxTakeProfitBPS: 100000, // 1000%
                leverageLevel: 0
            })
        );

        /**
            TestSettlementToken:
            constructor(
                string memory name_,
                string memory symbol_,
                uint256 faucetAmount_,
                uint256 faucetMinInterval_
            ) ERC20("", "")
        */
        contract_MockERC777 = new MockERC777(1000e18);

        contract_ChromaticMarketFactory.registerSettlementToken(
            address(contract_MockERC777),
            address(contract_ChainlinkFeedOracle), // oracleProvider
            1 ether, // minimumMargin
            1000, // interestRate, 10%
            500, // flashLoanFeeRate, 5%
            10 ether, // earningDistributionThreshold, $10
            3000 // uniswapFeeRate, 0.3%
        );

        contract_ChromaticMarketFactory.createMarket(
            address(contract_ChainlinkFeedOracle),
            address(contract_MockERC777)
        );
        contract_ChromaticMarket = ChromaticMarket(
            payable(contract_ChromaticMarketFactory.getMarkets()[0])
        );
        contract_CLBToken = CLBToken(
            address(IChromaticMarket(address(contract_ChromaticMarket)).clbToken())
        );

        contract_PriceFeedMock.setRoundData(1e18);
        vm.stopPrank();
    }

    function encodeId(int16 tradingFeeRate) internal pure returns (uint256) {
        bool long = tradingFeeRate > 0;
        return _encodeId(uint16(long ? tradingFeeRate : -tradingFeeRate), long);
    }

    function _encodeId(uint16 tradingFeeRate, bool long) private pure returns (uint256 id) {
        id = long ? tradingFeeRate : tradingFeeRate + (10 ** 10);
    }

    function _logLiquidityBins() internal {
        LiquidityBinStatus[] memory statuses = MarketLensFacet(address(contract_ChromaticMarket))
            .liquidityBinStatuses();
        uint256 sumPos;
        uint256 sumNeg;
        for (uint256 i; i < statuses.length; ++i) {
            console.log(StdStyle.red("\n"));
            if (statuses[i].tradingFeeRate > 0) {
                sumPos += statuses[i].freeLiquidity;
            } else {
                sumNeg += statuses[i].freeLiquidity;
            }
            console.log(
                StdStyle.red("TradingFeeRate -> %s"),
                vm.toString(statuses[i].tradingFeeRate)
            );
            console.log(StdStyle.red("Liquidity      -> %s"), vm.toString(statuses[i].liquidity));
            console.log(
                StdStyle.red("FreeLiquidity  -> %s"),
                vm.toString(statuses[i].freeLiquidity)
            );
            console.log(StdStyle.red("BinValue       -> %s"), vm.toString(statuses[i].binValue));
        }

        console.log("");
        console.log(StdStyle.red("Long free liq. -> %s"), vm.toString(sumPos));
        console.log(StdStyle.red("Short free liq.-> %s"), vm.toString(sumNeg));
    }

    function _logFreeLiquidity() internal {
        LiquidityBinStatus[] memory statuses = MarketLensFacet(address(contract_ChromaticMarket))
            .liquidityBinStatuses();
        uint256 sumPos;
        uint256 sumNeg;
        for (uint256 i; i < statuses.length; ++i) {
            if (statuses[i].tradingFeeRate > 0) {
                sumPos += statuses[i].freeLiquidity;
            } else {
                sumNeg += statuses[i].freeLiquidity;
            }
        }
        console.log("");
        console.log(StdStyle.red("Long free liq. -> %s"), vm.toString(sumPos));
        console.log(StdStyle.red("Short free liq.-> %s"), vm.toString(sumNeg));
    }

    function _getLongFreeLiquidity() internal returns (uint256) {
        LiquidityBinStatus[] memory statuses = MarketLensFacet(address(contract_ChromaticMarket))
            .liquidityBinStatuses();
        uint256 sumPos;
        uint256 sumNeg;
        for (uint256 i; i < statuses.length; ++i) {
            if (statuses[i].tradingFeeRate > 0) {
                sumPos += statuses[i].freeLiquidity;
            } else {
                sumNeg += statuses[i].freeLiquidity;
            }
        }

        return sumPos;
    }

    function _getShortFreeLiquidity() internal returns (uint256) {
        LiquidityBinStatus[] memory statuses = MarketLensFacet(address(contract_ChromaticMarket))
            .liquidityBinStatuses();
        uint256 sumPos;
        uint256 sumNeg;
        for (uint256 i; i < statuses.length; ++i) {
            if (statuses[i].tradingFeeRate > 0) {
                sumPos += statuses[i].freeLiquidity;
            } else {
                sumNeg += statuses[i].freeLiquidity;
            }
        }

        return sumNeg;
    }
}
