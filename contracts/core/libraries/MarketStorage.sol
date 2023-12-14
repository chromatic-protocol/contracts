// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {BinMargin} from "@chromatic-protocol/contracts/core/libraries/BinMargin.sol";

struct MarketStorage {
    IChromaticMarketFactory factory;
    IOracleProvider oracleProvider;
    IERC20Metadata settlementToken;
    ICLBToken clbToken;
    IChromaticVault vault;
    LiquidityPool liquidityPool;
    uint16 protocolFeeRate;
}

struct LpReceiptStorage {
    uint256 lpReceiptId;
    mapping(uint256 => LpReceipt) lpReceipts;
}

struct PositionStorage {
    uint256 positionId;
    mapping(uint256 => Position) positions;
}

library MarketStorageLib {
    bytes32 constant MARKET_STORAGE_POSITION = keccak256("protocol.chromatic.market.storage");

    function marketStorage() internal pure returns (MarketStorage storage ms) {
        bytes32 position = MARKET_STORAGE_POSITION;
        assembly {
            ms.slot := position
        }
    }
}

using LpReceiptStorageLib for LpReceiptStorage global;

library LpReceiptStorageLib {
    bytes32 constant LP_RECEIPT_STORAGE_POSITION =
        keccak256("protocol.chromatic.lpreceipt.storage");

    function lpReceiptStorage() internal pure returns (LpReceiptStorage storage ls) {
        bytes32 position = LP_RECEIPT_STORAGE_POSITION;
        assembly {
            ls.slot := position
        }
    }

    function nextId(LpReceiptStorage storage self) internal returns (uint256 id) {
        id = ++self.lpReceiptId;
    }

    function setReceipt(LpReceiptStorage storage self, LpReceipt memory receipt) internal {
        self.lpReceipts[receipt.id] = receipt;
    }

    function getReceipt(
        LpReceiptStorage storage self,
        uint256 receiptId
    ) internal view returns (LpReceipt memory receipt) {
        receipt = self.lpReceipts[receiptId];
    }

    function deleteReceipt(LpReceiptStorage storage self, uint256 receiptId) internal {
        delete self.lpReceipts[receiptId];
    }

    function deleteReceipts(LpReceiptStorage storage self, uint256[] memory receiptIds) internal {
        for (uint256 i; i < receiptIds.length; ) {
            delete self.lpReceipts[receiptIds[i]];

            unchecked {
                i++;
            }
        }
    }
}

using PositionStorageLib for PositionStorage global;

library PositionStorageLib {
    bytes32 constant POSITION_STORAGE_POSITION = keccak256("protocol.chromatic.position.storage");

    function positionStorage() internal pure returns (PositionStorage storage ls) {
        bytes32 position = POSITION_STORAGE_POSITION;
        assembly {
            ls.slot := position
        }
    }

    function nextId(PositionStorage storage self) internal returns (uint256 id) {
        id = ++self.positionId;
    }

    function setPosition(PositionStorage storage self, Position memory position) internal {
        Position storage _p = self.positions[position.id];

        _p.id = position.id;
        _p.openVersion = position.openVersion;
        _p.closeVersion = position.closeVersion;
        _p.qty = position.qty;
        _p.openTimestamp = position.openTimestamp;
        _p.closeTimestamp = position.closeTimestamp;
        _p.takerMargin = position.takerMargin;
        _p.owner = position.owner;
        _p.liquidator = position.liquidator;
        _p._protocolFeeRate = position._protocolFeeRate;
        // can not convert memory array to storage array
        delete _p._binMargins;
        for (uint i; i < position._binMargins.length; ) {
            BinMargin memory binMargin = position._binMargins[i];
            if (binMargin.amount != 0) {
                _p._binMargins.push(position._binMargins[i]);
            }

            unchecked {
                i++;
            }
        }
    }

    function getPosition(
        PositionStorage storage self,
        uint256 positionId
    ) internal view returns (Position memory position) {
        position = self.positions[positionId];
    }

    function getStoragePosition(
        PositionStorage storage self,
        uint256 positionId
    ) internal view returns (Position storage position) {
        position = self.positions[positionId];
    }

    function deletePosition(PositionStorage storage self, uint256 positionId) internal {
        delete self.positions[positionId];
    }
}
