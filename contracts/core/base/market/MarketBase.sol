// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IOracleProvider} from "@chromatic/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@chromatic/core/interfaces/IInterestCalculator.sol";
import {IChromaticMarketFactory} from "@chromatic/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic/core/interfaces/ICLBToken.sol";
import {IChromaticLiquidator} from "@chromatic/core/interfaces/IChromaticLiquidator.sol";
import {IChromaticVault} from "@chromatic/core/interfaces/IChromaticVault.sol";
import {IKeeperFeePayer} from "@chromatic/core/interfaces/IKeeperFeePayer.sol";
import {CLBTokenDeployerLib} from "@chromatic/core/external/deployer/CLBTokenDeployer.sol";
import {LiquidityPool} from "@chromatic/core/external/liquidity/LiquidityPool.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {LpReceipt} from "@chromatic/core/libraries/LpReceipt.sol";
import {Position} from "@chromatic/core/libraries/Position.sol";
import {Errors} from "@chromatic/core/libraries/Errors.sol";

/**
 * @title MarketBase
 * @dev Base contract for Chromatic markets.
 */
abstract contract MarketBase is IChromaticMarket, ReentrancyGuard {
    IChromaticMarketFactory public immutable override factory;
    IOracleProvider public immutable override oracleProvider;
    IERC20Metadata public immutable override settlementToken;

    ICLBToken public immutable override clbToken;
    IChromaticLiquidator public immutable override liquidator;
    IChromaticVault public immutable override vault;
    IKeeperFeePayer public immutable override keeperFeePayer;

    LiquidityPool internal liquidityPool;

    mapping(uint256 => Position) internal positions;
    mapping(uint256 => LpReceipt) internal lpReceipts;

    /**
     * @dev Modifier to restrict access to only the liquidator contract.
     */
    modifier onlyLiquidator() {
        require(msg.sender == address(liquidator), Errors.ONLY_LIQUIDATOR_CAN_ACCESS);
        _;
    }

    /**
     * @dev Initializes the market contract.
     */
    constructor() {
        factory = IChromaticMarketFactory(msg.sender);

        (address _oracleProvider, address _settlementToken) = factory.parameters();

        oracleProvider = IOracleProvider(_oracleProvider);
        settlementToken = IERC20Metadata(_settlementToken);
        clbToken = ICLBToken(CLBTokenDeployerLib.deploy());
        liquidator = IChromaticLiquidator(factory.liquidator());
        vault = IChromaticVault(factory.vault());
        keeperFeePayer = IKeeperFeePayer(factory.keeperFeePayer());

        liquidityPool.initialize();
    }

    /**
     * @dev Creates a new LP context.
     * @return The LP context.
     */
    function newLpContext() internal view returns (LpContext memory) {
        IOracleProvider.OracleVersion memory _currentVersionCache;
        return
            LpContext({
                oracleProvider: oracleProvider,
                interestCalculator: factory,
                vault: vault,
                clbToken: clbToken,
                market: address(this),
                settlementToken: address(settlementToken),
                tokenPrecision: 10 ** settlementToken.decimals(),
                _currentVersionCache: _currentVersionCache
            });
    }
}
