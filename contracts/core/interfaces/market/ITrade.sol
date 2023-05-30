// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
import {Position} from '@usum/core/libraries/Position.sol';

interface ITrade {
    error ZeroTargetAmount();
    error TooSmallTakerMargin();
    error NotEnoughMarginTransfered();
    error NotExistPosition();
    error NotPermitted();
    error AlreadyClosedPosition();
    error NotClaimablePosition();
    error ExceedMaxAllowableTradingFee();
    error ClaimPositionCallbackError();

    event OpenPosition(address indexed account, Position position);

    event ClosePosition(address indexed account, Position position);

    event ClaimPosition(address indexed account, int256 indexed pnl, uint256 indexed interest, Position position);

    event TransferProtocolFee(uint256 indexed positionId, uint256 indexed amount);

    event Liquidate(address indexed account, uint256 indexed usedKeeperFee, Position position);

    function openPosition(
        int224 qty,
        uint32 leverage, // BPS
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        bytes calldata data
    ) external returns (Position memory);

    function closePosition(uint256 positionId) external;

    function claimPosition(
        uint256 positionId,
        address recipient, // EOA or account contract
        bytes calldata data
    ) external;

    function getPositions(uint256[] calldata positionIds) external view returns (Position[] memory positions);
}
