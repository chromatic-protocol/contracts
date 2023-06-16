// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {PositionUtil} from "@chromatic-protocol/contracts/core/libraries/PositionUtil.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {BinMargin} from "@chromatic-protocol/contracts/core/libraries/BinMargin.sol";
import {MarketBase} from "@chromatic-protocol/contracts/core/base/market/MarketBase.sol";
import {IChromaticTradeCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticTradeCallback.sol";
import {ITrade} from "@chromatic-protocol/contracts/core/interfaces/market/ITrade.sol";
import {IMarketLiquidate} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketLiquidate.sol";

/**
 * @title Trade
 * @dev A contract that manages trading positions and liquidations.
 */
abstract contract Trade is MarketBase {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

    uint256 internal _positionId;

    /**
     * @inheritdoc ITrade
     */
    function openPosition(
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) external override nonReentrant returns (Position memory) {
        if (qty == 0) revert ZeroTargetAmount();

        uint256 minMargin = factory.getMinimumMargin(address(settlementToken));
        if (takerMargin < minMargin) revert TooSmallTakerMargin();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        Position memory position = newPosition(ctx, qty, leverage, takerMargin);

        position.setBinMargins(
            liquidityPool.prepareBinMargins(position.qty, makerMargin, minMargin)
        );

        // check trading fee
        uint256 tradingFee = position.tradingFee();

        if (tradingFee > maxAllowableTradingFee) {
            revert ExceedMaxAllowableTradingFee();
        }

        // call callback
        uint256 balanceBefore = settlementToken.balanceOf(address(vault));
        uint256 protocolFee = getProtocolFee(takerMargin);
        uint256 requiredMargin = takerMargin + protocolFee + tradingFee;
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

        vault.onOpenPosition(position.id, takerMargin, tradingFee, protocolFee);

        // write position
        position.storeTo(positions[position.id]);
        // create keeper task
        liquidator.createLiquidationTask(position.id);

        emit OpenPosition(position.owner, position);
        return position;
    }

    /**
     * @inheritdoc ITrade
     */
    function closePosition(uint256 positionId) external override {
        Position storage position = positions[positionId];
        if (position.id == 0) revert NotExistPosition();
        if (position.owner != msg.sender) revert NotPermitted();
        if (position.closeVersion != 0) revert AlreadyClosedPosition();

        LpContext memory ctx = newLpContext();

        position.closeVersion = ctx.currentOracleVersion().version;
        position.closeTimestamp = block.timestamp;

        liquidityPool.acceptClosePosition(ctx, position);
        liquidator.cancelLiquidationTask(position.id);
        emit ClosePosition(position.owner, position);

        if (position.closeVersion > position.openVersion) {
            liquidator.createClaimPositionTask(position.id);
        } else {
            // process claim if the position is closed in the same oracle version as the open version
            _claimPosition(ctx, position, 0, 0, position.owner, bytes(""));
        }
    }

    /**
     * @inheritdoc ITrade
     */
    function claimPosition(
        uint256 positionId,
        address recipient, // EOA or account contract
        bytes calldata data
    ) external override nonReentrant {
        Position memory position = positions[positionId];
        if (position.id == 0) revert NotExistPosition();
        if (position.owner != msg.sender) revert NotPermitted();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        if (!_checkClaimPosition(position, ctx)) revert NotClaimablePosition();

        _claimPosition(ctx, position, position.pnl(ctx), 0, recipient, data);

        liquidator.cancelClaimPositionTask(position.id);
    }

    /**
     * @inheritdoc IMarketLiquidate
     */
    function claimPosition(
        uint256 positionId,
        address keeper,
        uint256 keeperFee // native token amount
    ) external nonReentrant onlyLiquidator {
        Position memory position = positions[positionId];
        if (position.id == 0) revert NotExistPosition();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        if (!_checkClaimPosition(position, ctx)) revert NotClaimablePosition();

        uint256 usedKeeperFee = vault.transferKeeperFee(keeper, keeperFee, position.takerMargin);
        _claimPosition(ctx, position, position.pnl(ctx), usedKeeperFee, position.owner, bytes(""));

        liquidator.cancelClaimPositionTask(position.id);
    }

    /**
     * @inheritdoc IMarketLiquidate
     */
    function liquidate(
        uint256 positionId,
        address keeper,
        uint256 keeperFee // native token amount
    ) external nonReentrant onlyLiquidator {
        Position memory position = positions[positionId];
        if (position.id == 0) revert NotExistPosition();
        if (position.closeVersion != 0) revert AlreadyClosedPosition();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        (bool _liquidate, int256 _pnl) = _checkLiquidation(ctx, position);
        if (!_liquidate) return;

        uint256 usedKeeperFee = vault.transferKeeperFee(keeper, keeperFee, position.takerMargin);
        _claimPosition(ctx, position, _pnl, usedKeeperFee, position.owner, bytes(""));
        liquidator.cancelLiquidationTask(positionId);

        emit Liquidate(position.owner, usedKeeperFee, position);
    }

    /**
     * @dev Internal function for claiming a position.
     * @param ctx The LpContext containing the current oracle version and synchronization information.
     * @param position The Position object representing the position to be claimed.
     * @param pnl The profit or loss amount of the position.
     * @param usedKeeperFee The amount of the keeper fee used.
     * @param recipient The address of the recipient (EOA or account contract) receiving the settlement.
     * @param data Additional data for the claim position callback.
     */
    function _claimPosition(
        LpContext memory ctx,
        Position memory position,
        int256 pnl,
        uint256 usedKeeperFee,
        address recipient,
        bytes memory data
    ) internal {
        uint256 makerMargin = position.makerMargin();
        uint256 takerMargin = position.takerMargin - usedKeeperFee;
        uint256 settlementAmount = takerMargin;

        // Calculate the interest based on the maker margin and the time difference
        // between the open timestamp and the current block timestamp
        uint256 interest = ctx.calculateInterest(
            makerMargin,
            position.openTimestamp,
            block.timestamp
        );
        // Calculate the realized profit or loss by subtracting the interest from the total pnl
        int256 realizedPnl = pnl - interest.toInt256();
        uint256 absRealizedPnl = realizedPnl.abs();
        if (realizedPnl > 0) {
            if (absRealizedPnl > makerMargin) {
                // If the absolute value of the realized pnl is greater than the maker margin,
                // set the realized pnl to the maker margin and add the maker margin to the settlement
                realizedPnl = makerMargin.toInt256();
                settlementAmount += makerMargin;
            } else {
                settlementAmount += absRealizedPnl;
            }
        } else {
            if (absRealizedPnl > takerMargin) {
                // If the absolute value of the realized pnl is greater than the taker margin,
                // set the realized pnl to the negative taker margin and set the settlement amount to 0
                realizedPnl = -(takerMargin.toInt256());
                settlementAmount = 0;
            } else {
                settlementAmount -= absRealizedPnl;
            }
        }

        // Accept the claim position in the liquidity pool
        liquidityPool.acceptClaimPosition(ctx, position, realizedPnl);

        // Call the onClaimPosition function in the vault to handle the settlement
        vault.onClaimPosition(position.id, recipient, takerMargin, settlementAmount);

        // Call the claim position callback function on the position owner's contract
        // If an exception occurs during the callback, revert the transaction unless the caller is the liquidator
        try
            IChromaticTradeCallback(position.owner).claimPositionCallback(position.id, data)
        {} catch (bytes memory e /*lowLevelData*/) {
            if (msg.sender != address(liquidator)) {
                revert ClaimPositionCallbackError();
            }
        }
        // Delete the claimed position from the positions mapping
        delete positions[position.id];

        emit ClaimPosition(position.owner, pnl, interest, position);
    }

    /**
     * @inheritdoc IMarketLiquidate
     */
    function checkLiquidation(uint256 positionId) external view returns (bool _liquidate) {
        Position memory position = positions[positionId];
        if (position.id == 0) return false;

        (_liquidate, ) = _checkLiquidation(newLpContext(), position);
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
                position.leveragedQty(ctx),
                position.entryPrice(ctx),
                PositionUtil.oraclePrice(ctx.currentOracleVersion())
            ) -
            interest.toInt256();

        uint256 absPnl = _pnl.abs();
        if (_pnl > 0) {
            // whether profit stop (taker side)
            _liquidate = absPnl >= position.makerMargin();
        } else {
            // whether loss cut (taker side)
            _liquidate = absPnl >= position.takerMargin;
        }
    }

    /**
     * @inheritdoc IMarketLiquidate
     */
    function checkClaimPosition(uint256 positionId) external view returns (bool) {
        Position memory position = positions[positionId];
        if (position.id == 0) return false;

        return _checkClaimPosition(position, newLpContext());
    }

    /**
     * @dev Internal function for checking if a position can be claimed.
     * @param position The Position object representing the position to be checked.
     * @param ctx The LpContext containing the current oracle version and synchronization information.
     * @return A boolean indicating whether the position can be claimed.
     */
    function _checkClaimPosition(
        Position memory position,
        LpContext memory ctx
    ) internal view returns (bool) {
        return
            position.closeVersion > 0 && position.closeVersion < ctx.currentOracleVersion().version;
    }

    function getProtocolFee(uint256 margin) public view returns (uint16) {
        // returns (protocolFeeRate)
        // FIXME: TBA
        return 0;
    }

    /**
     * @dev Creates a new position.
     * @param ctx The LP context.
     * @param qty The quantity of the position.
     * @param leverage The leverage of the position.
     * @param takerMargin The margin provided by the taker.
     * @return The newly created position.
     */
    function newPosition(
        LpContext memory ctx,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin
    ) private returns (Position memory) {
        return
            Position({
                id: ++_positionId,
                openVersion: ctx.currentOracleVersion().version,
                closeVersion: 0,
                qty: qty, //
                leverage: leverage,
                openTimestamp: block.timestamp,
                closeTimestamp: 0,
                takerMargin: takerMargin,
                owner: msg.sender,
                _binMargins: new BinMargin[](0)
            });
    }

    /**
     * @inheritdoc ITrade
     */
    function getPositions(
        uint256[] calldata positionIds
    ) external view returns (Position[] memory _positions) {
        _positions = new Position[](positionIds.length);
        for (uint i = 0; i < positionIds.length; i++) {
            _positions[i] = positions[positionIds[i]];
        }
    }
}
