// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {LpSlotMargin} from "@usum/core/libraries/LpSlotMargin.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {PositionUtil} from "@usum/core/libraries/PositionUtil.sol";
import {IUSUMTradeCallback} from "@usum/core/interfaces/callback/IUSUMTradeCallback.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {MarketValue} from "@usum/core/base/market/MarketValue.sol";
import {OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";

abstract contract Trade is MarketValue {
    using Math for uint256;
    using SafeCast for int256;
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
        uint256 takerMargin, // include losscut
        uint256 makerMargin, // include profit stop
        // uint16 profitstop, // in bps ex) 10% = 1000
        // uint16 lossCut, // bps
        bytes calldata data
    ) external returns (Position memory) {
        if (quantity == 0) revert ZeroTargetAmount();
        //TODO get slotmargin by using makerMargin
        // calc protocol fee

        LpContext memory lpContext = newLpContext();
        Position memory position = Position({
            id: _positionId++,
            oracleVersion: lpContext.currentOracleVersion().version,
            qty: quantity.toInt224(), //
            leverage: leverage,
            timestamp: block.timestamp,
            takerMargin: takerMargin,
            owner: msg.sender,
            _slotMargins: new LpSlotMargin[](0)
        });

        // position._slotMargins

        uint256 protocolFee = getProtocolFee(takerMargin);

        lpSlotSet.prepareSlotMargins(position, makerMargin);
        // call callback
        uint256 balanceBefore = _balance();
        uint256 requiredMargin = takerMargin +
            protocolFee +
            position.tradingFee();
        IUSUMTradeCallback(msg.sender).openPositionCallback(
            address(settlementToken),
            requiredMargin,
            data
        );
        // check margin settlementToken increased
        if (balanceBefore + requiredMargin < _balance())
            revert NotEnoughMarginTransfered();

        lpSlotSet.acceptOpenPosition(lpContext, position);

        transferProtocolFee(position.id, protocolFee);

        // write position
        position.storeTo(positions[position.id]);

        //TODO add event parameters
        emit OpenPosition();
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
        ) - interestFee.toInt256();

        uint256 makerMargin = position.makerMargin();
        uint256 takerMargin = position.takerMargin;

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

        lpSlotSet.acceptClosePosition(lpContext, position, realizedPnl);

        transferMargin(takerMargin, recipient);

        return takerMargin;
    }

    function _incrementPositionId() internal returns (uint256) {
        _positionId++;
        return _positionId;
    }

    function _calcInterestFee(
        Position memory position
    ) internal view returns (uint256) {
        return
            calculateInterest(
                position.makerMargin(),
                position.timestamp,
                block.timestamp
            );
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
}