// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticLiquidator} from "@chromatic-protocol/contracts/core/interfaces/IChromaticLiquidator.sol";
import {IOracleProviderRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/IOracleProviderRegistry.sol";
import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {IMarketTrade} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTrade.sol";
import {IVault} from "@chromatic-protocol/contracts/core/interfaces/vault/IVault.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {BinMargin} from "@chromatic-protocol/contracts/core/libraries/BinMargin.sol";
import {QTY_PRECISION, QTY_LEVERAGE_PRECISION} from "@chromatic-protocol/contracts/core/libraries/PositionUtil.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {MarketStorage, MarketStorageLib, PositionStorage, PositionStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {BPS} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {MarketTradeFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeFacetBase.sol";

/**
 * @title MarketTradeFacet
 * @dev A contract that manages trading positions.
 */
contract MarketTradeFacet is MarketTradeFacetBase, IMarketTrade, ReentrancyGuard {
    using Math for uint256;
    using SignedMath for int256;

    error ZeroTargetAmount();
    error TooSmallTakerMargin();
    error NotEnoughMarginTransfered();
    error NotPermitted();
    error AlreadyClosedPosition();
    error NotClaimablePosition();
    error ExceedMaxAllowableTradingFee();
    error ExceedMaxAllowableLeverage();
    error NotAllowableTakerMargin();
    error NotAllowableMakerMargin();

    /**
     * @inheritdoc IMarketTrade
     */
    function openPosition(
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) external override nonReentrant returns (Position memory position) {
        if (qty == 0) revert ZeroTargetAmount();

        MarketStorage storage ms = MarketStorageLib.marketStorage();
        IChromaticMarketFactory factory = ms.factory;
        LiquidityPool storage liquidityPool = ms.liquidityPool;

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        uint256 minMargin = factory.getMinimumMargin(ctx.settlementToken);
        if (takerMargin < minMargin) revert TooSmallTakerMargin();

        _checkPositionParam(
            ctx,
            qty,
            leverage,
            takerMargin,
            makerMargin,
            factory.getOracleProviderProperties(address(ctx.oracleProvider))
        );

        position = _newPosition(ctx, qty, leverage, takerMargin, ms.feeProtocol);
        position.setBinMargins(
            liquidityPool.prepareBinMargins(position.qty, makerMargin, minMargin)
        );

        _openPosition(ctx, liquidityPool, position, maxAllowableTradingFee, data);

        // write position
        PositionStorageLib.positionStorage().setPosition(position);
        // create keeper task
        ms.liquidator.createLiquidationTask(position.id);

        emit OpenPosition(position.owner, position);
    }

    function _checkPositionParam(
        LpContext memory ctx,
        int256 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        IOracleProviderRegistry.OracleProviderProperties memory properties
    ) private pure {
        if (leverage > (properties.leverageLevel + 1) * 10 * QTY_LEVERAGE_PRECISION)
            revert ExceedMaxAllowableLeverage();

        uint256 absQty = qty.abs().mulDiv(ctx.tokenPrecision, QTY_PRECISION);
        if (
            takerMargin < absQty.mulDiv(properties.minStopLossBPS, BPS) ||
            takerMargin > absQty.mulDiv(properties.maxStopLossBPS, BPS)
        ) revert NotAllowableTakerMargin();
        if (
            makerMargin < absQty.mulDiv(properties.minTakeProfitBPS, BPS) ||
            makerMargin > absQty.mulDiv(properties.maxTakeProfitBPS, BPS)
        ) revert NotAllowableMakerMargin();
    }

    function _openPosition(
        LpContext memory ctx,
        LiquidityPool storage liquidityPool,
        Position memory position,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) private {
        // check trading fee
        uint256 tradingFee = position.tradingFee();
        uint256 protocolFee = position.protocolFee();
        if (tradingFee + protocolFee > maxAllowableTradingFee) {
            revert ExceedMaxAllowableTradingFee();
        }

        IERC20Metadata settlementToken = IERC20Metadata(ctx.settlementToken);
        IVault vault = ctx.vault;

        // call callback
        uint256 balanceBefore = settlementToken.balanceOf(address(vault));

        uint256 requiredMargin = position.takerMargin + protocolFee + tradingFee;
        IChromaticTradeCallback(msg.sender).openPositionCallback(
            address(settlementToken),
            address(vault),
            requiredMargin,
            data
        );
        // check margin settlementToken increased
        if (balanceBefore + requiredMargin < settlementToken.balanceOf(address(vault)))
            revert NotEnoughMarginTransfered();

        liquidityPool.acceptOpenPosition(ctx, position); // settle()

        vault.onOpenPosition(
            address(settlementToken),
            position.id,
            position.takerMargin,
            tradingFee,
            protocolFee
        );
    }

    /**
     * @inheritdoc IMarketTrade
     */
    function closePosition(uint256 positionId) external override {
        Position storage position = PositionStorageLib.positionStorage().getStoragePosition(
            positionId
        );
        if (position.id == 0) revert NotExistPosition();
        if (position.owner != msg.sender) revert NotPermitted();
        if (position.closeVersion != 0) revert AlreadyClosedPosition();

        MarketStorage storage ms = MarketStorageLib.marketStorage();
        LiquidityPool storage liquidityPool = ms.liquidityPool;
        IChromaticLiquidator liquidator = ms.liquidator;

        LpContext memory ctx = newLpContext(ms);

        position.closeVersion = ctx.currentOracleVersion().version;
        position.closeTimestamp = block.timestamp;

        liquidityPool.acceptClosePosition(ctx, position);
        liquidator.cancelLiquidationTask(position.id);

        emit ClosePosition(position.owner, position);

        if (position.closeVersion > position.openVersion) {
            liquidator.createClaimPositionTask(position.id);
        } else {
            // process claim if the position is closed in the same oracle version as the open version
            uint256 interest = _claimPosition(ctx, position, 0, 0, position.owner, bytes(""));
            emit ClaimPosition(position.owner, 0, interest, position);
        }
    }

    /**
     * @inheritdoc IMarketTrade
     */
    function claimPosition(
        uint256 positionId,
        address recipient, // EOA or account contract
        bytes calldata data
    ) external override nonReentrant {
        Position memory position = _getPosition(PositionStorageLib.positionStorage(), positionId);
        if (position.owner != msg.sender) revert NotPermitted();

        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        if (!ctx.isPastVersion(position.closeVersion)) revert NotClaimablePosition();

        int256 pnl = position.pnl(ctx);
        uint256 interest = _claimPosition(ctx, position, pnl, 0, recipient, data);
        emit ClaimPosition(position.owner, pnl, interest, position);

        ms.liquidator.cancelClaimPositionTask(position.id);
    }

    /**
     * @inheritdoc IMarketTrade
     */
    function getPositions(
        uint256[] calldata positionIds
    ) external view returns (Position[] memory _positions) {
        PositionStorage storage ps = PositionStorageLib.positionStorage();

        _positions = new Position[](positionIds.length);
        for (uint i; i < positionIds.length; ) {
            _positions[i] = ps.getPosition(positionIds[i]);

            unchecked {
                i++;
            }
        }
    }

    function _newPosition(
        LpContext memory ctx,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint8 feeProtocol
    ) private returns (Position memory) {
        PositionStorage storage ps = PositionStorageLib.positionStorage();

        return
            Position({
                id: ps.nextId(),
                openVersion: ctx.currentOracleVersion().version,
                closeVersion: 0,
                qty: qty, //
                leverage: leverage,
                openTimestamp: block.timestamp,
                closeTimestamp: 0,
                takerMargin: takerMargin,
                owner: msg.sender,
                _binMargins: new BinMargin[](0),
                _feeProtocol: feeProtocol
            });
    }
}
