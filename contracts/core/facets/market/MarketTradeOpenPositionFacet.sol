// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {PositionMode} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {IMarketTradeOpenPosition} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTradeOpenPosition.sol";
import {OpenPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {BinMargin} from "@chromatic-protocol/contracts/core/libraries/BinMargin.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {MarketStorage, MarketStorageLib, PositionStorage, PositionStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {BPS} from "@chromatic-protocol/contracts/core/libraries/Constants.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {OracleProviderProperties} from "@chromatic-protocol/contracts/core/libraries/registry/OracleProviderProperties.sol";
import {MarketFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketFacetBase.sol";

/**
 * @title MarketTradeOpenPositionFacet
 * @dev A contract that manages trading positions.
 */
contract MarketTradeOpenPositionFacet is
    ReentrancyGuard,
    MarketFacetBase,
    IMarketTradeOpenPosition
{
    using Math for uint256;
    using SignedMath for int256;

    uint256 constant LEVERAGE_DECIMALS = 2;
    uint256 constant LEVERAGE_PRECISION = 10 ** LEVERAGE_DECIMALS;

    /**
     * @inheritdoc IMarketTradeOpenPosition
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
    )
        external
        override
        nonReentrant
        withTradingLock
        returns (OpenPositionInfo memory positionInfo)
    {
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        _requireOpenPositionEnabled(ms);

        IChromaticMarketFactory factory = ms.factory;
        address liquidator = factory.liquidator();
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

        Position memory position = _newPosition(
            ctx,
            qty,
            takerMargin,
            ms.protocolFeeRate,
            liquidator
        );
        position.setBinMargins(
            liquidityPool.prepareBinMargins(ctx, position.qty, makerMargin, minMargin)
        );

        positionInfo = _openPosition(ctx, liquidityPool, position, maxAllowableTradingFee, data);

        // write position
        PositionStorageLib.positionStorage().setPosition(position);
        // create keeper task
        ILiquidator(liquidator).createLiquidationTask(position.id);

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
        IChromaticVault vault = ctx.vault;

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
        if (requiredMargin < settlementToken.balanceOf(address(vault)) - balanceBefore)
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

    function _newPosition(
        LpContext memory ctx,
        int256 qty,
        uint256 takerMargin,
        uint16 protocolFeeRate,
        address liquidator
    ) internal returns (Position memory) {
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
                liquidator: liquidator,
                _protocolFeeRate: protocolFeeRate,
                _binMargins: new BinMargin[](0)
            });
    }

    /**
     * @dev Throws if open position is disabled.
     */
    function _requireOpenPositionEnabled(MarketStorage storage ms) internal view virtual {
        PositionMode mode = ms.positionMode;
        if (mode == PositionMode.OpenDisabled || mode == PositionMode.Suspended) {
            revert OpenPositionDisabled();
        }
    }
}
