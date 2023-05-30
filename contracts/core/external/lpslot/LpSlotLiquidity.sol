// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {DoubleEndedQueue} from '@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol';
import {IOracleProvider} from '@usum/core/interfaces/IOracleProvider.sol';
import {USUMLpToken} from '@usum/core/USUMLpToken.sol';
import {LpContext} from '@usum/core/libraries/LpContext.sol';
import {Errors} from '@usum/core/libraries/Errors.sol';

import 'forge-std/console.sol';

struct LpSlotLiquidity {
    uint256 total;
    _PendingLiquidity _pending;
    mapping(uint256 => _ClaimMinting) _claimMintings;
    mapping(uint256 => _ClaimBurning) _claimBurnings;
    DoubleEndedQueue.Bytes32Deque _burningVersions;
}

struct _PendingLiquidity {
    uint256 oracleVersion;
    uint256 tokenAmount;
    uint256 lpTokenAmount;
}

struct _ClaimMinting {
    uint256 tokenAmount;
    uint256 mintingAmount;
}

struct _ClaimBurning {
    uint256 lpTokenAmount;
    uint256 burningAmount;
    uint256 tokenAmount;
}

library LpSlotLiquidityLib {
    using Math for uint256;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    /// @dev Minimum amount constant to prevent division by zero.
    uint256 private constant MIN_AMOUNT = 1000;

    function settlePendingLiquidity(
        LpSlotLiquidity storage self,
        LpContext memory ctx,
        uint256 slotValue,
        uint256 freeLiquidity,
        uint256 lpTokenId
    ) internal {
        uint256 oracleVersion = self._pending.oracleVersion;
        if (oracleVersion == 0) return;

        IOracleProvider.OracleVersion memory currentVersion = ctx.currentOracleVersion();
        if (oracleVersion >= currentVersion.version) return;

        USUMLpToken lpToken = ctx.market.lpToken();
        uint256 totalSupply = lpToken.totalSupply(lpTokenId);

        uint256 pendingDeposit = self._pending.tokenAmount;
        uint256 pendingLpTokenAmount = self._pending.lpTokenAmount;

        uint256 mintingAmount = _settlePending(
            self,
            pendingDeposit,
            pendingLpTokenAmount,
            slotValue,
            totalSupply,
            oracleVersion
        );

        (uint256 burningAmount, uint256 pendingWithdrawal) = _settleBurning(
            self,
            freeLiquidity + pendingDeposit,
            slotValue,
            totalSupply
        );

        if (mintingAmount > burningAmount) {
            lpToken.mint(address(ctx.market), lpTokenId, mintingAmount - burningAmount, bytes(''));
        } else if (mintingAmount < burningAmount) {
            lpToken.burn(address(ctx.market), lpTokenId, burningAmount - mintingAmount);
        }

        ctx.market.vault().onSettlePendingLiquidity(pendingDeposit, pendingWithdrawal);

        delete self._pending;
    }

    function onAddLiquidity(LpSlotLiquidity storage self, uint256 amount, uint256 oracleVersion) internal {
        require(amount > MIN_AMOUNT, Errors.TOO_SMALL_AMOUNT);

        uint256 pendingOracleVersion = self._pending.oracleVersion;
        require(pendingOracleVersion == 0 || pendingOracleVersion == oracleVersion, Errors.INVALID_ORACLE_VERSION);

        self._pending.oracleVersion = oracleVersion;
        self._pending.tokenAmount += amount;
    }

    function onClaimLpToken(
        LpSlotLiquidity storage self,
        uint256 amount,
        uint256 oracleVersion
    ) internal returns (uint256 lpTokenAmount) {
        _ClaimMinting memory _cm = self._claimMintings[oracleVersion];
        lpTokenAmount = amount.mulDiv(_cm.mintingAmount, _cm.tokenAmount);

        _cm.mintingAmount -= lpTokenAmount;
        _cm.tokenAmount -= amount;
        if (_cm.tokenAmount == 0) {
            delete self._claimMintings[oracleVersion];
        } else {
            self._claimMintings[oracleVersion] = _cm;
        }
    }

    function calculateLpTokenMinting(
        uint256 amount,
        uint256 slotValue,
        uint256 lpTokenTotalSupply
    ) internal pure returns (uint256) {
        return
            lpTokenTotalSupply == 0
                ? amount
                : amount.mulDiv(lpTokenTotalSupply, slotValue < MIN_AMOUNT ? MIN_AMOUNT : slotValue);
    }

    function calculateLpTokenValue(
        uint256 lpTokenAmount,
        uint256 slotValue,
        uint256 lpTokenTotalSupply
    ) internal pure returns (uint256) {
        return lpTokenAmount.mulDiv(slotValue, lpTokenTotalSupply);
    }

    function _settlePending(
        LpSlotLiquidity storage self,
        uint256 pendingDeposit,
        uint256 pendingLpTokenAmount,
        uint256 slotValue,
        uint256 totalSupply,
        uint256 oracleVersion
    ) private returns (uint256 mintingAmount) {
        if (pendingDeposit > 0) {
            mintingAmount = calculateLpTokenMinting(pendingDeposit, slotValue, totalSupply);

            self.total += pendingDeposit;
            self._claimMintings[oracleVersion] = _ClaimMinting({
                tokenAmount: pendingDeposit,
                mintingAmount: mintingAmount
            });
        }

        if (pendingLpTokenAmount > 0) {
            self._burningVersions.pushBack(bytes32(oracleVersion));
            self._claimBurnings[oracleVersion] = _ClaimBurning({
                lpTokenAmount: pendingLpTokenAmount,
                burningAmount: 0,
                tokenAmount: 0
            });
        }
    }

    function _settleBurning(
        LpSlotLiquidity storage self,
        uint256 freeLiquidity,
        uint256 slotValue,
        uint256 totalSupply
    ) private returns (uint256 burningAmount, uint256 pendingWithdrawal) {
        // trim all claim completed burning versions
        while (!self._burningVersions.empty()) {
            uint256 _ov = uint256(self._burningVersions.front());
            _ClaimBurning memory _cb = self._claimBurnings[_ov];
            if (_cb.lpTokenAmount == 0) {
                delete self._claimBurnings[_ov];
                self._burningVersions.popFront();
            } else if (_cb.burningAmount >= _cb.lpTokenAmount) {
                self._burningVersions.popFront();
            } else {
                break;
            }
        }

        uint256 length = self._burningVersions.length();
        for (uint256 i = 0; i < length && freeLiquidity > 0; i++) {
            uint256 _ov = uint256(self._burningVersions.at(i));
            _ClaimBurning storage _cb = self._claimBurnings[_ov];

            uint256 _pendingLpTokenAmount = _cb.lpTokenAmount - _cb.burningAmount;
            if (_pendingLpTokenAmount > 0) {
                uint256 _burningAmount;
                uint256 _pendingWithdrawal = calculateLpTokenValue(_pendingLpTokenAmount, slotValue, totalSupply);
                if (freeLiquidity >= _pendingWithdrawal) {
                    _burningAmount = _pendingLpTokenAmount;
                } else {
                    _burningAmount = calculateLpTokenMinting(freeLiquidity, slotValue, totalSupply);
                    require(_burningAmount < _pendingLpTokenAmount);
                    _pendingWithdrawal = freeLiquidity;
                }

                _cb.burningAmount += _burningAmount;
                _cb.tokenAmount += _pendingWithdrawal;

                burningAmount += _burningAmount;
                pendingWithdrawal += _pendingWithdrawal;
                freeLiquidity -= _pendingWithdrawal;
            }
        }

        self.total -= pendingWithdrawal;
    }
}
