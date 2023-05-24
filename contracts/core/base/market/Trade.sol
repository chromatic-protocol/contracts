// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotMargin} from "@usum/core/libraries/LpSlotMargin.sol";
import {MarketValue} from "@usum/core/base/market/MarketValue.sol";
import {IUSUMTradeCallback} from "@usum/core/interfaces/callback/IUSUMTradeCallback.sol";
import {ITrade} from "@usum/core/interfaces/market/ITrade.sol";

abstract contract Trade is MarketValue {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

    uint256 internal _positionId;

    ///@inheritdoc ITrade
    function openPosition(
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) external override nonReentrant returns (Position memory) {
        if (qty == 0) revert ZeroTargetAmount();
        if (
            takerMargin <
            factory.getMinimumTakerMargin(address(settlementToken))
        ) revert TooSmallTakerMargin();
        //TODO get slotmargin by using makerMargin

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        Position memory position = newPosition(ctx, qty, leverage, takerMargin);

        position.setSlotMargins(
            lpSlotSet.prepareSlotMargins(position.qty, makerMargin)
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
        IUSUMTradeCallback(msg.sender).openPositionCallback(
            address(settlementToken),
            address(vault),
            requiredMargin,
            data
        );
        // check margin settlementToken increased
        if (
            balanceBefore + requiredMargin <
            settlementToken.balanceOf(address(vault))
        ) revert NotEnoughMarginTransfered();

        lpSlotSet.acceptOpenPosition(ctx, position); // settle()

        vault.onOpenPosition(position.id, takerMargin, tradingFee, protocolFee);

        // write position
        position.storeTo(positions[position.id]);
        // create keeper task
        liquidator.createLiquidationTask(position.id);

        emit OpenPosition(position.owner, position);
        return position;
    }

    function closePosition(uint256 positionId) external override {
        Position storage position = positions[positionId];
        if (position.id == 0) revert NotExistPosition();
        if (position.owner != msg.sender) revert NotPermitted();
        if (position.closeVersion != 0) revert AlreadyClosedPosition();

        LpContext memory ctx = newLpContext();

        position.closeVersion = ctx.currentOracleVersion().version;
        position.closeTimestamp = block.timestamp;

        lpSlotSet.acceptClosePosition(ctx, position);
        liquidator.cancelLiquidationTask(position.id);
        emit ClosePosition(position.owner, position);

        if (position.closeVersion > position.openVersion) {
            liquidator.createClaimPositionTask(position.id);
        } else {
            // process claim if the position is closed in the same oracle version as the open version
            _claimPosition(ctx, position, 0, position.owner, bytes(""));
        }
    }

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

        _claimPosition(ctx, position, 0, recipient, data);

        liquidator.cancelClaimPositionTask(position.id);
    }

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

        uint256 usedKeeperFee = vault.transferKeeperFee(
            keeper,
            keeperFee,
            position.takerMargin
        );
        _claimPosition(ctx, position, usedKeeperFee, position.owner, bytes(""));

        liquidator.cancelClaimPositionTask(position.id);
    }

    function liquidate(
        uint256 positionId,
        address keeper,
        uint256 keeperFee // native token amount
    ) external nonReentrant onlyLiquidator {
        liquidator.cancelLiquidationTask(positionId);

        Position memory position = positions[positionId];
        if (position.id == 0) revert NotExistPosition();
        if (position.closeVersion != 0) revert AlreadyClosedPosition();

        LpContext memory ctx = newLpContext();
        ctx.syncOracleVersion();

        if (!_checkLiquidation(ctx, position)) return;

        uint256 usedKeeperFee = vault.transferKeeperFee(
            keeper,
            keeperFee,
            position.takerMargin
        );
        _claimPosition(ctx, position, usedKeeperFee, position.owner, bytes(""));

        emit Liquidate(position.owner, position, usedKeeperFee);
    }

    function _claimPosition(
        LpContext memory ctx,
        Position memory position,
        uint256 usedKeeperFee,
        address recipient,
        bytes memory data
    ) internal {
        uint256 makerMargin = position.makerMargin();
        uint256 takerMargin = position.takerMargin - usedKeeperFee;
        uint256 settlementAmount = takerMargin;

        int256 pnl = position.pnl(ctx);
        uint256 interest = calculateInterest(
            makerMargin,
            position.openTimestamp,
            block.timestamp
        );
        int256 realizedPnl = pnl - interest.toInt256();

        uint256 absRealizedPnl = realizedPnl.abs();
        if (realizedPnl > 0) {
            if (absRealizedPnl > makerMargin) {
                realizedPnl = makerMargin.toInt256();
                settlementAmount += makerMargin;
            } else {
                settlementAmount += absRealizedPnl;
            }
        } else {
            if (absRealizedPnl > takerMargin) {
                realizedPnl = -(takerMargin.toInt256());
                settlementAmount = 0;
            } else {
                settlementAmount -= absRealizedPnl;
            }
        }

        lpSlotSet.acceptClaimPosition(ctx, position, realizedPnl);

        vault.onClaimPosition(
            position.id,
            recipient,
            takerMargin,
            settlementAmount
        );

        // TODO keeper == msg.sender => revert 시 정상처리 (강제청산)
        try
            IUSUMTradeCallback(position.owner).claimPositionCallback(
                position.id,
                data
            )
        {} catch (bytes memory e /*lowLevelData*/) {
            if (msg.sender != address(liquidator)) {
                revert ClaimPositionCallbackError();
            }
        }
        delete positions[position.id];

        emit ClaimPosition(position.owner, position, pnl, interest);
    }

    function checkLiquidation(uint256 positionId) external view returns (bool) {
        Position memory position = positions[positionId];
        if (position.id == 0) return false;

        return _checkLiquidation(newLpContext(), position);
    }

    function _checkLiquidation(
        LpContext memory ctx,
        Position memory position
    ) internal view returns (bool) {
        uint256 interest = calculateInterest(
            position.makerMargin(),
            position.openTimestamp,
            block.timestamp
        );

        int256 pnl = PositionUtil.pnl(
            position.leveragedQty(ctx),
            position.entryPrice(ctx),
            PositionUtil.oraclePrice(ctx.currentOracleVersion())
        ) - interest.toInt256();
        uint256 absPnl = pnl.abs();
        if (pnl > 0) {
            // whether profit stop (taker side)
            return absPnl >= position.makerMargin();
        } else {
            // whether loss cut (taker side)
            return absPnl >= position.takerMargin;
        }
    }

    function checkClaimPosition(
        uint256 positionId
    ) external view returns (bool) {
        Position memory position = positions[positionId];
        if (position.id == 0) return false;

        return _checkClaimPosition(position, newLpContext());
    }

    function _checkClaimPosition(
        Position memory position,
        LpContext memory ctx
    ) internal view returns (bool) {
        return
            position.closeVersion > 0 &&
            position.closeVersion < ctx.currentOracleVersion().version;
    }

    function getProtocolFee(uint256 margin) public view returns (uint16) {
        // returns (protocolFeeRate)
        // FIXME: TBA
        return 0;
    }

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
                _slotMargins: new LpSlotMargin[](0)
            });
    }

    function getPosition(
        uint256 positionId
    ) external view override returns (Position memory position) {
        position = positions[positionId];
    }
}
