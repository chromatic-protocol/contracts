// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ILiquidator} from "@chromatic-protocol/contracts/core/interfaces/ILiquidator.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {PositionUtil} from "@chromatic-protocol/contracts/core/libraries/PositionUtil.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {MarketStorage, MarketStorageLib, PositionStorageLib} from "@chromatic-protocol/contracts/core/libraries/MarketStorage.sol";
import {MarketTradeFacetBase} from "@chromatic-protocol/contracts/core/facets/market/MarketTradeFacetBase.sol";
import {OpenPositionInfo, ClosePositionInfo, ClaimPositionInfo, CLAIM_USER, CLAIM_KEEPER, CLAIM_SL, CLAIM_TP} from "@chromatic-protocol/contracts/core/interfaces/market/Types.sol";

/**
 * @title MarketLiquidateFacet
 * @dev A contract that manages liquidations.
 */
contract MarketLiquidateFacet is ReentrancyGuard, MarketTradeFacetBase, IMarketLiquidate {
    using SafeCast for uint256;
    using SignedMath for int256;

    /**
     * @inheritdoc IMarketLiquidate
     * @dev This function can only be called by the chromatic liquidator contract.
     *      Throws a `NotExistPosition` error if the requested position does not exist.
     *      Throws a `NotClaimablePosition` error if the position's close version is not in the past, indicating that it is not claimable.
     */
    function claimPosition(
        uint256 positionId,
        address keeper,
        uint256 keeperFee // native token amount
    ) external override nonReentrant withTradingLock {
        Position memory position = _getPosition(PositionStorageLib.positionStorage(), positionId);
        if (msg.sender != position.liquidator) revert OnlyAccessableByLiquidator();

        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        if (!ctx.isPastVersion(position.closeVersion)) revert NotClaimablePosition();

        uint256 usedKeeperFee = keeperFee != 0
            ? ctx.vault.transferKeeperFee(
                ctx.settlementToken,
                keeper,
                keeperFee,
                position.takerMargin
            )
            : 0;
        int256 pnl = position.pnl(ctx);
        uint256 interest = _claimPosition(
            ctx,
            position,
            pnl,
            usedKeeperFee,
            position.owner,
            bytes(""),
            CLAIM_KEEPER
        );
        emit ClaimPositionByKeeper(position.owner, pnl, interest, usedKeeperFee, position);

        ILiquidator(position.liquidator).cancelClaimPositionTask(position.id);
    }

    /**
     * @inheritdoc IMarketLiquidate
     * @dev This function can only be called by the chromatic liquidator contract.
     *      The liquidation process checks if the position should be liquidated based on its profitability.
     *      If the position does not meet the liquidation criteria, the function returns without performing any action.
     *      Throws a `NotExistPosition` error if the requested position does not exist.
     *      Throws an `AlreadyClosedPosition` error if the position is already closed.
     */
    function liquidate(
        uint256 positionId,
        address keeper,
        uint256 keeperFee // native token amount
    ) external override nonReentrant withTradingLock {
        Position memory position = _getPosition(PositionStorageLib.positionStorage(), positionId);
        if (msg.sender != position.liquidator) revert OnlyAccessableByLiquidator();
        if (position.closeVersion != 0) revert AlreadyClosedPosition();

        MarketStorage storage ms = MarketStorageLib.marketStorage();

        LpContext memory ctx = newLpContext(ms);
        ctx.syncOracleVersion();

        (bool _liquidate, int256 _pnl) = _checkLiquidation(ctx, position);
        if (!_liquidate) return;

        uint256 usedKeeperFee = keeperFee != 0
            ? ctx.vault.transferKeeperFee(
                ctx.settlementToken,
                keeper,
                keeperFee,
                position.takerMargin
            )
            : 0;
        uint256 interest = _claimPosition(
            ctx,
            position,
            _pnl,
            usedKeeperFee,
            position.owner,
            bytes(""),
            _pnl > 0 ? CLAIM_TP : CLAIM_SL
        );

        ILiquidator(position.liquidator).cancelLiquidationTask(positionId);

        emit Liquidate(position.owner, _pnl, interest, usedKeeperFee, position);
    }

    /**
     * @inheritdoc IMarketLiquidate
     */
    function checkLiquidation(uint256 positionId) external view override returns (bool _liquidate) {
        Position memory position = PositionStorageLib.positionStorage().getPosition(positionId);
        if (position.id == 0) return false;

        (_liquidate, ) = _checkLiquidation(
            newLpContext(MarketStorageLib.marketStorage()),
            position
        );
    }

    /**
     * @dev Internal function for checking if a position should be liquidated.
     * @param ctx The LpContext containing the current oracle version and synchronization information.
     * @param position The Position object representing the position to be checked.
     * @return _liquidate A boolean indicating whether the position should be liquidated.
     * @return _pnl The profit or loss amount of the position.
     */
    function _checkLiquidation(
        LpContext memory ctx,
        Position memory position
    ) internal view returns (bool _liquidate, int256 _pnl) {
        uint256 interest = ctx.calculateInterest(
            position.makerMargin(),
            position.openTimestamp,
            block.timestamp
        );

        _pnl =
            PositionUtil.pnl(
                position.qty,
                position.entryPrice(ctx),
                PositionUtil.oraclePrice(ctx.currentOracleVersion())
            ) -
            interest.toInt256();

        uint256 absPnl = _pnl.abs();
        //slither-disable-next-line timestamp
        if (_pnl > 0) {
            // whether profit stop (taker side)
            //slither-disable-next-line timestamp
            _liquidate = absPnl >= position.makerMargin();
        } else {
            // whether loss cut (taker side)
            //slither-disable-next-line timestamp
            _liquidate = absPnl >= position.takerMargin;
        }
    }

    /**
     * @inheritdoc IMarketLiquidate
     */
    function checkClaimPosition(uint256 positionId) external view override returns (bool) {
        Position memory position = PositionStorageLib.positionStorage().getPosition(positionId);
        if (position.id == 0) return false;

        return newLpContext(MarketStorageLib.marketStorage()).isPastVersion(position.closeVersion);
    }
}
