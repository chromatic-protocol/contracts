// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {LpSlotPosition} from "@usum/core/libraries/LpSlotPosition.sol";
import {LpSlot} from "@usum/core/libraries/LpSlot.sol";
import {LpSlotKey} from "@usum/core/libraries/LpSlotKey.sol";
import {LpSlotMargin, LpSlotMarginLib} from "@usum/core/libraries/LpSlotMargin.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {LpSlotPendingPosition, LpSlotPendingPositionLib} from "@usum/core/libraries/LpSlotPendingPosition.sol";
import {PositionParam} from "@usum/core/libraries/PositionParam.sol";
import {IUSUMTradeCallback} from "@usum/core/interfaces/callback/IUSUMTradeCallback.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {MarketValue} from "@usum/core/base/market/MarketValue.sol";
import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {IInterestCalculator} from "@usum/core/interfaces/IInterestCalculator.sol";
import {ISettlementTokenRegistry} from "@usum/core/interfaces/ISettlementTokenRegistry.sol";

abstract contract Trade is MarketValue {
    using Math for uint256;
    using SafeCast for int256;
    using SafeCast for uint256;

    error ZeroTargetAmount();

    error InvalidProfitStop();
    error InvalidLossCut();
    error LossCutNotRequired();
    error InvalidLeverage();
    error InvalidBasis();

    error NotEnoughMarginTransfered();
    error NotExistPosition();
    error NotPermitted();

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
        int256 quantity,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        // uint16 profitstop, // in bps ex) 10% = 1000
        // uint16 lossCut, // bps
        bytes calldata data
    ) external returns (Position memory) {
        if (quantity == 0) revert ZeroTargetAmount();
        //TODO get slotmargin by using makerMargin

        // calc protocol fee

        OracleVersion memory currentOracleVersion = oracleProvider
            .currentVersion();
        PositionParam memory positionParam = PositionParam({
            oracleVersion: currentOracleVersion.version,
            leveragedQty: quantity * int32(leverage),
            takerMargin: takerMargin,
            makerMargin: makerMargin,
            timestamp: block.timestamp,
            _settleVersionCache: OracleVersion({
                version: 0,
                timestamp: 0,
                price: 0
            })
        });
        Position memory position = Position({
            id: _positionId++,
            oracleVersion: positionParam.oracleVersion,
            qty: quantity.toInt224(), //
            timestamp: block.timestamp,
            leverage: leverage,
            takerMargin: takerMargin,
            _slotMargins: new LpSlotMargin[](0),
            owner: msg.sender
        });
        LpContext memory lpContext = newLpContext();
        lpSlotSet.prepareSlotMargins(position, makerMargin);
        lpSlotSet.acceptOpenPosition(lpContext, position);
        // position._slotMargins
        uint256 protocolFee = getProtocolFeeRate();

        // call callback
        uint256 balanceBefore = _balance();

        IUSUMTradeCallback(msg.sender).openPositionCallback(
            address(settlementToken),
            takerMargin + protocolFee,
            data
        );
        // check margin settlementToken increased
        if (balanceBefore + takerMargin + position.tradingFee() > _balance())
            revert NotEnoughMarginTransfered();

        transferProtocolFee(position.id, protocolFee);

        // write position
        positions[position.id] = position;

        // TODO emit event

        return position;
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
        uint256 marginTransferred = _closePosition(position, recipient);

        IUSUMTradeCallback(msg.sender).closePositionCallback(
            address(settlementToken),
            marginTransferred,
            data
        );
        
        delete positions[position.id];
        emit ClosePosition();
    }

    function _closePosition(
        Position memory position,
        address recipient
    ) internal returns (uint256 marginTransferred) {
        //TODO close position
        LpContext memory lpContext = newLpContext();
        uint256 interestFee = _calcInterestFee(position);
        int256 realizedPnl = PositionUtil.pnl(
            position.leveragedQty(lpContext),
            PositionUtil.entryPrice(oracleProvider, position.oracleVersion),
            PositionUtil.oraclePrice(oracleProvider.currentVersion())
        );
        lpSlotSet.acceptClosePosition(lpContext, position, realizedPnl);

        realizedPnl -= interestFee.toInt256();
        int256 takerMargin = position.takerMargin.toInt256();
        if(takerMargin > 0){
            transferMargin(takerMargin, realizedPnl, recipient);
        }
        return 0;
    }

    function _incrementPositionId() internal returns (uint256) {
        _positionId++;
        return _positionId;
    }

    function _calcInterestFee(
        Position memory position
    ) internal view returns (uint256) {
        return
            ISettlementTokenRegistry(address(factory)).calculateInterest(
                address(settlementToken),
                position.makerMargin(),
                position.timestamp,
                block.timestamp
            );
    }

    function transferMargin(
        int256 takerMargin,
        int256 pnl,
        address recipient
    ) internal returns (uint256 marginTransferred) {
        int256 takerLeftMargin = takerMargin + pnl;

        if (takerLeftMargin <= 0) {
            return 0;
        }

        uint256 transferred = uint256(takerLeftMargin);
        SafeERC20.safeTransfer(
            address(settlementToken),
            recipient,
            transferred
        );
        return transferred;
    }

    function getProtocolFeeRate() internal view returns (uint16) {
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
}
