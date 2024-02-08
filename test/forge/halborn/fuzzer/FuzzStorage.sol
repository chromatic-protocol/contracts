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
import {Mate2Liquidator} from "@chromatic-protocol/contracts/core/automation/Mate2Liquidator.sol";
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
import {FuzzRandomizer} from "./FuzzRandomizer.sol";

abstract contract FuzzStorage is Test {
    using Strings for *;

    FuzzRandomizer public contract_FuzzRandomizer;

    string public ARB_RPC_URL = "https://arb-mainnet.g.alchemy.com/v2/dc67PtVCdrbbiu40eIihsiS9w1oOnLKO";
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
    ChromaticMarket public contract_ChromaticMarket;
    CLBToken public contract_CLBToken;
    Mate2Liquidator public contract_Mate2Liquidator;

    // Users
    IAutomate public _automate = IAutomate(address(5555));
    address public owner = vm.addr(100);

    // Valid fee rates
    uint16[36] public validFeeRates = [
      uint16(1), uint16(2), uint16(3), uint16(4), uint16(5), uint16(6), uint16(7), uint16(8), uint16(9), // 0.01% ~ 0.09%, step 0.01%
      uint16(10), uint16(20), uint16(30), uint16(40), uint16(50), uint16(60), uint16(70), uint16(80), uint16(90), // 0.1% ~ 0.9%, step 0.1%
      uint16(100), uint16(200), uint16(300), uint16(400), uint16(500), uint16(600), uint16(700), uint16(800), uint16(900), // 1% ~ 9%, step 1%
      uint16(1000), uint16(1500), uint16(2000), uint16(2500), uint16(3000), uint16(3500), uint16(4000), uint16(4500), uint16(5000) // 10% ~ 50%, step 5%
    ];

    // All fee rates
    int16[] public allFeeRates;

    // Tokens
    IERC20 public contract_WETH = IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

    // Misc
    address public constant UNISWAPV3 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    /*_________________________________
      FUZZING
      _________________________________
    */
    uint256 public constant STATES = 50;
    uint256 public constant MAKERS = 40;
    uint256 public constant TAKERS = 100;
    bool public enableDebugToFile = true;
    string public line;
    string public constant initPath = "./test/forge/halborn/fuzzer/startId.txt";
    string public path;
    // Array of users
    address[] public state_makers;
    address[] public state_takers;
    uint256 public currentOraclePrice = 1e18;
    // Private keys for each user
    mapping(address => uint256) state_PrivateKeys;
    // Mapping to set a private key as used
    mapping(uint256 => bool) PK_used;
    // User -> token address -> initial balance
    mapping(address => mapping(address => uint256)) state_initialBalances;
    // Positions opened since day 0
    uint256[] public state_positionsSinceDay0;
    // Positions opened since day 0
    uint256[] public state_allLpReceiptsOracleVersionsFromRemoveLiq;
    // Opened positions
    mapping(address => uint256[]) state_openedPositions;
    // Claimable positions
    mapping(address => uint256[]) state_claimablePositions;
    // FeeRates deposited
    mapping(address => int16[]) state_feeRatesDepos;
    // Claimable deposits
    mapping(address => uint256[]) state_claimableDepos;
    // Claimable withdrawals
    mapping(address => uint256[]) state_claimableWithdrawals;

    uint256 public constant ONE_HUNDRED_PERCENT = 10000;
    uint256 public constant LOW_THRESHOLD_ST_MAKER_BALANCE = 10e18;
    uint256 public constant HIGH_THRESHOLD_ST_MAKER_BALANCE = 1000000e18;
    uint256 public constant LOW_THRESHOLD_ST_TAKER_BALANCE = 1e18;
    uint256 public constant HIGH_THRESHOLD_ST_TAKER_BALANCE = 100000e18;

    event Debug(string a);
    event DebugAddr(string a, address b);
    event DebugUint(string a, uint256 b);
    event ErrorReturnData(bytes errorData);
    event DebugStateCreated(uint256 iteration, address user, uint256 PK, uint256 initialSetlementTokenBalance, uint256 timestamp);
    event DebugPositionOpened(address user, uint256 id, int256 QTY, uint256 takerMargin, uint256 makerMargin, uint256 timestamp);
    event DebugPositionOpenedFailed(address user, uint256 timestamp, string reason);
    event DebugPositionClosed(address user, uint256 id, uint256 timestamp);
    event DebugPositionClosedFailed(address user, uint256 timestamp, string reason);
    event DebugPositionClaimed(address user, uint256 id, uint256 timestamp);
    event DebugPositionClaimedFailed(address user, uint256 timestamp, string reason);
    event DebugLiquidityAdded(address user, uint256 id, int16 selectedFeeRate, uint256 collateralAmount, uint256 timestamp);
    event DebugLiquidityAddedFailed(address user, uint256 timestamp, string reason);
    event DebugLiquidityRemoved(address user, uint256 id, int16 selectedFeeRate, uint256 collateralAmount, uint256 timestamp);
    event DebugLiquidityRemovedFailed(address user, uint256 timestamp, string reason);
    event DebugLiquidityClaimed(address user, uint256 id, uint256 timestamp);
    event DebugLiquidityWithdrawn(address user, uint256 id, uint256 receivedAmount, uint256 timestamp);
    event DebugLiquidityWithdrawnFailed(address user, uint256 timestamp, string reason);
}