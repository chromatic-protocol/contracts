// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotMargin} from "@usum/core/libraries/LpSlotMargin.sol";
import {MarketValue} from "@usum/core/base/market/MarketValue.sol";
import {TransferKeeperFee} from "@usum/core/base/market/TransferKeeperFee.sol";
import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMTradeCallback} from "@usum/core/interfaces/callback/IUSUMTradeCallback.sol";

abstract contract Trade is MarketValue {
    using Math for uint256;
    using SafeCast for uint256;
    using SignedMath for int256;

    error ZeroTargetAmount();

    error InvalidProfitStop();
    error InvalidLossCut();
    error LossCutNotRequired();
    error InvalidLeverage();
    error InvalidBasis();

    error NotEnoughMarginTransfered();
    error NotExistPosition();
    error NotPermitted();
    error ExceedMaxAllowableTradingFee();

    error ClosePositionCallbackError();

    event OpenPosition();
    event ClosePosition();

    struct ClosePositionInfo {
        int256 takerPosition;
        uint256 exitPrice;
        int256 takerPnl;
        uint256 totalFee;
        address recipient;
    }

    event TransferProtocolFee();

    // constants
    // uint32 public constant MIN_LEVERAGE_BPS = uint32(BPS);
    // uint32 public constant MAX_LEVERAGE_BPS = 1000 * uint32(BPS);

    // uint16 public constant MIN_PROFITSTOP_BPS = 1; // 0.01%
    // uint16 public constant MAX_PROFITSTOP_BPS = type(uint16).max; // uint16(BPS); // 100%

    uint256 internal _positionId;

    function openPosition(
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) external returns (Position memory) {
        if (qty == 0) revert ZeroTargetAmount();
        //TODO get slotmargin by using makerMargin

        LpContext memory ctx = newLpContext();
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
        uint256 balanceBefore = _balance();
        uint256 protocolFee = getProtocolFee(takerMargin);
        uint256 requiredMargin = takerMargin + protocolFee + tradingFee;
        IUSUMTradeCallback(msg.sender).openPositionCallback(
            address(settlementToken),
            requiredMargin,
            data
        );
        // check margin settlementToken increased
        if (balanceBefore + requiredMargin < _balance())
            revert NotEnoughMarginTransfered();

        lpSlotSet.acceptOpenPosition(ctx, position); // settle()

        transferProtocolFee(position.id, protocolFee);

        // write position
        position.storeTo(positions[position.id]);
        // create keeper task
        liquidator.createLiquidationTask(position.id);

        //TODO add event parameters
        emit OpenPosition();
        return position;
    }

    modifier resolvePendingPositions() {
        _;
        // for loop
        //
        // ~
        // struct 체결여부 : 단순조회용
        // uint256[] pendingTakerPositionIds 관리
    }

    // can call keeper or onwer only
    function closePosition(
        uint256 positionId,
        address recipient, // EOA or account contract
        bytes calldata data
    ) external {
        Position memory position = positions[positionId];
        if (position.id == 0) revert NotExistPosition();
        // TODO caller keeper || owner
        if (position.owner != msg.sender) revert NotPermitted();
        uint256 marginTransferred = _closePosition(
            position,
            0,
            recipient,
            data
        );

        liquidator.cancelLiquidationTask(position.id);

        emit ClosePosition();
    }

    function _closePosition(
        Position memory position,
        uint256 usedKeeperFee, // TODO
        address recipient,
        bytes memory data
    ) internal returns (uint256 marginTransferred) {
        //TODO close position
        LpContext memory ctx = newLpContext();

        uint256 makerMargin = position.makerMargin();
        uint256 takerMargin = position.takerMargin;

        uint256 interestFee = calculateInterest(
            makerMargin,
            position.timestamp,
            block.timestamp
        );
        int256 realizedPnl = position.pnl(ctx) - interestFee.toInt256();

        uint256 absRealizedPnl = realizedPnl.abs();
        if (realizedPnl > 0) {
            if (absRealizedPnl > makerMargin) {
                realizedPnl = makerMargin.toInt256();
                takerMargin += makerMargin;
            } else {
                takerMargin += absRealizedPnl;
            }
        } else {
            if (absRealizedPnl > position.takerMargin) {
                realizedPnl = -(position.takerMargin.toInt256());
                takerMargin = 0;
            } else {
                takerMargin -= absRealizedPnl;
            }
        }

        lpSlotSet.acceptClosePosition(ctx, position, realizedPnl);

        transferMargin(takerMargin, recipient);

        // TODO keeper == msg.sender => revert 시 정상처리 (강제청산)
        try
            IUSUMTradeCallback(position.owner).closePositionCallback(
                address(this),
                position.id,
                data
            )
        {} catch {
            if(msg.sender != address(liquidator)){
                revert ClosePositionCallbackError();
            }
        }

        delete positions[position.id];

        return takerMargin;
    }

    function transferMargin(uint256 takerMargin, address recipient) internal {
        SafeERC20.safeTransfer(
            address(settlementToken),
            recipient,
            takerMargin
        );
    }

    function getProtocolFee(uint256 margin) public view returns (uint16) {
        // returns (protocolFeeRate)
        // FIXME: TBA
        return 0;
    }

    function transferProtocolFee(uint256 positionId, uint256 amount) internal {
        // FIXME: get DAO address
        address dao;

        if (amount > 0) {
            SafeERC20.safeTransfer(
                address(settlementToken),
                dao,
                uint256(amount)
            );
            emit TransferProtocolFee();
        }
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
                oracleVersion: ctx.currentOracleVersion().version,
                qty: qty, //
                leverage: leverage,
                timestamp: block.timestamp,
                takerMargin: takerMargin,
                owner: msg.sender,
                _slotMargins: new LpSlotMargin[](0)
            });
    }

    function liquidate(
        uint256 positionId,
        uint256 usedKeeperFee
    ) external onlyLiquidator {
        Position memory position = positions[positionId];
        if (position.id == 0) revert NotExistPosition();
        _closePosition(position, usedKeeperFee, position.owner, bytes(""));
    }

    function checkLiquidation(uint256 positionId) external view returns (bool) {
        Position memory position = positions[positionId];
        if (position.id == 0) return false;

        uint256 interestFee = calculateInterest(
            position.makerMargin(),
            position.timestamp,
            block.timestamp
        );

        int256 realizedPnl = position.pnl(newLpContext()) -
            interestFee.toInt256();
        uint256 absRealizedPnl = realizedPnl.abs();
        if (realizedPnl > 0 && absRealizedPnl >= position.makerMargin()) {
            //profit stop (taker side)
            return true;
        } else if (absRealizedPnl >= position.takerMargin) {
            // loss cut (taker side)
            return true;
        }
        return false;
    }

    function getPosition(
        uint256 positionId
    ) external view override returns (Position memory position) {
        position = positions[positionId];
    }
}
