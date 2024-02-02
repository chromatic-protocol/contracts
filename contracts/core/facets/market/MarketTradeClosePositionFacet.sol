// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {PositionMode} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IMarketTradeClosePosition} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTradeClosePosition.sol";
import {ClosePositionInfo, CLAIM_USER} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {MarketStorage, MarketStorageLib, PositionStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {MarketTradeFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeFacetBase.sol";

/**
 * @title MarketTradeClosePositionFacet
 * @dev A contract that manages trading positions.
 */
contract MarketTradeClosePositionFacet is MarketTradeFacetBase, IMarketTradeClosePosition, ReentrancyGuard {
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

    error OpenPositionDisabled();
    error ClosePositionDisabled();

    /**
     * @inheritdoc IMarketTradeClosePosition
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
        MarketStorage storage ms = MarketStorageLib.marketStorage();
        _requireClosePositionEnabled(ms);

        Position storage position = PositionStorageLib.positionStorage().getStoragePosition(
            positionId
        );
        if (position.id == 0) revert NotExistPosition();
        if (position.owner != msg.sender) revert NotPermitted();
        if (position.closeVersion != 0) revert AlreadyClosedPosition();

        LiquidityPool storage liquidityPool = ms.liquidityPool;
        ILiquidator liquidator = ILiquidator(position.liquidator);

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
     * @inheritdoc IMarketTradeClosePosition
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

        ILiquidator(position.liquidator).cancelClaimPositionTask(position.id);
    }

    /**
     * @dev Throws if close position is disabled.
     */
    function _requireClosePositionEnabled(MarketStorage storage ms) internal view virtual {
        PositionMode mode = ms.positionMode;
        if (mode == PositionMode.CloseDisabled || mode == PositionMode.Suspended) {
            revert ClosePositionDisabled();
        }
    }
}
