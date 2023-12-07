// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IOracleProviderRegistry} from "@chromatic-protocol/contracts/core/interfaces/factory/IOracleProviderRegistry.sol";
import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {IMarketTrade} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTrade.sol";
import {OpenPositionInfo, ClosePositionInfo, ClaimPositionInfo, CLAIM_USER, CLAIM_KEEPER, CLAIM_SL, CLAIM_TP} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {IVault} from "@chromatic-protocol/contracts/core/interfaces/vault/IVault.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {BinMargin} from "@chromatic-protocol/contracts/core/libraries/BinMargin.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {MarketStorage, MarketStorageLib, PositionStorage, PositionStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {BPS} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {OracleProviderProperties} from "@chromatic-protocol/contracts/core/libraries/registry/OracleProviderProperties.sol";
import {MarketTradeFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeFacetBase.sol";

/**
 * @title MarketTradeFacet
 * @dev A contract that manages trading positions.
 */
contract MarketTradeFacet is MarketTradeFacetBase, IMarketTrade, ReentrancyGuard {
    using Math for uint256;
    using SignedMath for int256;

    uint256 constant LEVERAGE_DECIMALS = 2;
    uint256 constant LEVERAGE_PRECISION = 10 ** LEVERAGE_DECIMALS;

    /**
     * @dev Throws an error indicating that the taker margin provided is smaller than the minimum required margin for the specific settlement token.
     *      The minimum required margin is determined by the DAO and represents the minimum amount required for operations such as liquidation and payment of keeper fees.
     */
    error TooSmallTakerMargin();

    /**
     * @dev Throws an error indicating that the margin settlement token balance does not increase by the required margin amount after the callback.
     */
    error NotEnoughMarginTransferred();

    /**
     * @dev Throws an error indicating that the caller is not permitted to perform the action as they are not the owner of the position.
     */
    error NotPermitted();

    /**
     * @dev Throws an error indicating that the position has already been closed and cannot be closed again.
     */
    error AlreadyClosedPosition();

    /**
     * @dev Throws an error indicating that the position cannot be claimed as it is not eligible for claim in the current oracle version.
     */
    error NotClaimablePosition();

    /**
     * @dev Throws an error indicating that the total trading fee (including protocol fee) exceeds the maximum allowable trading fee.
     */
    error ExceedMaxAllowableTradingFee();

    /**
     * @dev Throws an error indicating thatwhen the specified leverage exceeds the maximum allowable leverage level set by the Oracle Provider.
     *      Each Oracle Provider has a specific maximum allowable leverage level, which is determined by the DAO.
     *      The default maximum allowable leverage level is 0, which corresponds to a leverage of up to 10x.
     */
    error ExceedMaxAllowableLeverage();

    /**
     * @dev Throws an error indicating that the maker margin value is not within the allowable range based on the absolute quantity and the specified minimum/maximum take-profit basis points (BPS).
     *      The maker margin must fall within the range calculated based on the absolute quantity of the position and the specified minimum/maximum take-profit basis points (BPS) set by the Oracle Provider.
     *      The default range for the minimum/maximum take-profit basis points is 10% to 1000%.
     */
    error NotAllowableMakerMargin();

    /**
     * @inheritdoc IMarketTrade
     * @dev Throws a `TooSmallTakerMargin` error if the `takerMargin` is smaller than the minimum required margin for the settlement token.
     *      Throws an `ExceedMaxAllowableLeverage` if the leverage exceeds the maximum allowable leverage.
     *      Throws a `NotAllowableMakerMargin` if the maker margin is not within the allowable range based on the absolute quantity and min/max take-profit basis points (BPS).
     *      Throws an `ExceedMaxAllowableTradingFee` if the total trading fee (including protocol fee) exceeds the maximum allowable trading fee (`maxAllowableTradingFee`).
     *      Throws a `NotEnoughMarginTransferred` if the margin settlement token balance did not increase by the required margin amount after the callback.
     *
     * Requirements:
     *  - The `takerMargin` must be greater than or equal to the minimum required margin for the settlement token.
     *  - The position parameters must pass the validity check, including leverage limits and allowable margin ranges.
     *  - The position is assigned a new ID and stored in the position storage.
     *  - A keeper task for potential liquidation is created by the liquidator.
     *  - An `OpenPosition` event is emitted with the owner's address and the newly opened position details.
     */
    function openPosition(
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) external override nonReentrant returns (OpenPositionInfo memory positionInfo) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        IChromaticMarketFactory factory = ms.factory;
        LiquidityPool storage liquidityPool = ms.liquidityPool;

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        uint256 minMargin = factory.getMinimumMargin(ctx.settlementToken);
        if (takerMargin < minMargin) revert TooSmallTakerMargin();

        _checkPositionParam(
            qty,
            takerMargin,
            makerMargin,
            factory.getOracleProviderProperties(address(ctx.oracleProvider))
        );

        Position memory position = _newPosition(ctx, qty, takerMargin, ms.feeProtocol);
        position.setBinMargins(
            liquidityPool.prepareBinMargins(ctx, position.qty, makerMargin, minMargin)
        );

        positionInfo = _openPosition(ctx, liquidityPool, position, maxAllowableTradingFee, data);

        // write position
        PositionStorageLib.positionStorage().setPosition(position);
        // create keeper task
        ms.liquidator.createLiquidationTask(position.id);

        emit OpenPosition(position.owner, position);
    }

    function _checkPositionParam(
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        OracleProviderProperties memory properties
    ) private pure {
        uint256 absQty = qty.abs();
        uint256 leverage = absQty.mulDiv(LEVERAGE_PRECISION, takerMargin);

        uint256 maxAllowableLeverage = properties.maxAllowableLeverage();
        if (leverage > maxAllowableLeverage * LEVERAGE_PRECISION)
            revert ExceedMaxAllowableLeverage();

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
    ) private returns (OpenPositionInfo memory openInfo) {
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
            revert NotEnoughMarginTransferred();

        liquidityPool.acceptOpenPosition(ctx, position); // settle()

        vault.onOpenPosition(
            address(settlementToken),
            position.id,
            position.takerMargin,
            tradingFee,
            protocolFee
        );

        openInfo = OpenPositionInfo({
            id: position.id,
            openVersion: position.openVersion,
            qty: position.qty,
            openTimestamp: position.openTimestamp,
            takerMargin: position.takerMargin,
            makerMargin: position.makerMargin(),
            tradingFee: tradingFee + protocolFee
        });
    }

    /**
     * @inheritdoc IMarketTrade
     * @dev This function allows the owner of the position to close it. The position must exist, be owned by the caller,
     *      and not have already been closed. Upon successful closure, the position is settled, and a `ClosePosition` event is emitted.
     *      If the position is closed in a different oracle version than the open version, a claim position task is created by the liquidator.
     *      Otherwise, the position is immediately claimed, and a `ClaimPosition` event is emitted.
     *      Throws a `NotExistPosition` error if the specified position does not exist.
     *      Throws a `NotPermitted` error if the caller is not the owner of the position.
     *      Throws an `AlreadyClosedPosition` error if the position has already been closed.
     *      Throws a `ClaimPositionCallbackError` error if an error occurred during the claim position callback.
     */
    function closePosition(
        uint256 positionId
    ) external override nonReentrant returns (ClosePositionInfo memory closed) {
        Position storage position = PositionStorageLib.positionStorage().getStoragePosition(
            positionId
        );
        if (position.id == 0) revert NotExistPosition();
        if (position.owner != msg.sender) revert NotPermitted();
        if (position.closeVersion != 0) revert AlreadyClosedPosition();

        MarketStorage storage ms = MarketStorageLib.marketStorage();
        LiquidityPool storage liquidityPool = ms.liquidityPool;
        ILiquidator liquidator = ms.liquidator;

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        position.closeVersion = ctx.currentOracleVersion().version;
        position.closeTimestamp = block.timestamp;

        liquidityPool.acceptClosePosition(ctx, position);
        liquidator.cancelLiquidationTask(position.id);

        emit ClosePosition(position.owner, position);

        if (position.closeVersion > position.openVersion) {
            liquidator.createClaimPositionTask(position.id);
        } else {
            // process claim if the position is closed in the same oracle version as the open version
            uint256 interest = _claimPosition(
                ctx,
                position,
                0,
                0,
                position.owner,
                bytes(""),
                CLAIM_USER
            );
            emit ClaimPosition(position.owner, 0, interest, position);
        }
        closed = ClosePositionInfo({
            id: position.id,
            closeVersion: position.closeVersion,
            closeTimestamp: position.closeTimestamp
        });
    }

    /**
     * @inheritdoc IMarketTrade
     * @dev Claims the position by transferring the available funds to the recipient.
     *      The caller must be the owner of the position.
     *      The position must be eligible for claim in the current oracle version.
     *      The claimed amount is determined based on the position's profit and loss (pnl).
     *      Throws a `NotExistPosition` error if the requested position does not exist.
     *      Throws a `NotPermitted` error if the caller is not permitted to perform the action as they are not the owner of the position.
     *      Throws a `NotClaimablePosition` error if the position cannot be claimed as it is not eligible for claim in the current oracle version.
     *      Throws a `ClaimPositionCallbackError` error if an error occurred during the claim position callback.
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
        uint256 interest = _claimPosition(ctx, position, pnl, 0, recipient, data, CLAIM_USER);
        emit ClaimPosition(position.owner, pnl, interest, position);

        ms.liquidator.cancelClaimPositionTask(position.id);
    }

    function _newPosition(
        LpContext memory ctx,
        int256 qty,
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
                openTimestamp: block.timestamp,
                closeTimestamp: 0,
                takerMargin: takerMargin,
                owner: msg.sender,
                _binMargins: new BinMargin[](0),
                _feeProtocol: feeProtocol
            });
    }
}
