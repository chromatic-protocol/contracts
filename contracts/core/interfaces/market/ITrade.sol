// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
import {Position} from 'core/libraries/Position.sol';


interface ITrade {
     function openPosition(
        int256 quantity,
        uint32 leverage, // BPS
        uint256 takerMargin,
        uint256 makerMargin,
        bytes calldata data
    ) external returns (Position memory);
     
     function closePosition(
        uint256 positionId,
        address recipient, // EOA or account contract
        bytes calldata data
    ) external;
}