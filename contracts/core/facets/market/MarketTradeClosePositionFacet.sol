// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
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
contract MarketTradeClosePositionFacet is
    ReentrancyGuard,
    MarketTradeFacetBase,
    IMarketTradeClosePosition
{
    using Math for uint256;
    using SignedMath for int256;

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
    ) external override nonReentrant withTradingLock returns (ClosePositionInfo memory closed) {
        MarketStorage storage ms = MarketStorageLib.marketStorage();

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
    ) external override nonReentrant withTradingLock {
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
}
