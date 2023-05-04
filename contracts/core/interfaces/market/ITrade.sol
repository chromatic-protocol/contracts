// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
import {Position} from "@usum/core/libraries/Position.sol";

interface ITrade {

    error ZeroTargetAmount();
    error TooSmallTakerMargin();
    error NotEnoughMarginTransfered();
    error NotExistPosition();
    error NotPermitted();
    error ExceedMaxAllowableTradingFee();
    error ClosePositionCallbackError();
    
    event OpenPosition(address indexed account, uint256 oracleVersion, Position position);
    event ClosePosition(address indexed account, uint256 oracleVersion, Position position, int256 realizedPnl);
    event TransferProtocolFee(uint256 positionId, uint256 amount);
    event Liquidate(uint256 positionId, uint256 usedKeeperFee);

    function openPosition(
        int224 qty,
        uint32 leverage, // BPS
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) external returns (Position memory);

    function closePosition(
        uint256 positionId,
        address recipient, // EOA or account contract
        bytes calldata data
    ) external;

    function getPosition(
        uint256 positionId
    ) external view returns (Position memory position);
}
