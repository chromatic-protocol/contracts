// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from '@openzeppelin/contracts/utils/math/Math.sol';
import {DoubleEndedQueue} from '@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol';
import {IOracleProvider} from '@usum/core/interfaces/IOracleProvider.sol';
import {USUMLpToken} from '@usum/core/USUMLpToken.sol';
import {LpContext} from '@usum/core/libraries/LpContext.sol';
import {Errors} from '@usum/core/libraries/Errors.sol';

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

        uint256 mintingAmount;
        uint256 pendingDeposit = self._pending.tokenAmount;
        if (pendingDeposit > 0) {
            mintingAmount = _settleMinting(self, pendingDeposit, slotValue, totalSupply, oracleVersion);
            totalSupply += mintingAmount;
            freeLiquidity += pendingDeposit;
        }

        uint256 burningAmount;
        uint256 pendingWithdrawal;
        uint256 pendingLpTokenAmount = self._pending.lpTokenAmount;
        if (pendingLpTokenAmount > 0) {
            (burningAmount, pendingWithdrawal) = _settleBurning(
                self,
                pendingLpTokenAmount,
                freeLiquidity,
                slotValue,
                totalSupply,
                oracleVersion
            );
        }

        if (mintingAmount > burningAmount) {
            ctx.market.lpToken().mint(address(ctx.market), lpTokenId, mintingAmount - burningAmount, bytes(''));
        } else if (mintingAmount < burningAmount) {
            ctx.market.lpToken().burn(address(ctx.market), lpTokenId, burningAmount - mintingAmount);
        }

        ctx.market.vault().onSettlePendingLiquidity(pendingDeposit, pendingWithdrawal);

        delete self._pending;
    }

    function onAddLiquidity(LpSlotLiquidity storage self, uint256 amount, uint256 oracleVersion) internal {
        require(amount > MIN_AMOUNT, Errors.TOO_SMALL_AMOUNT);

        uint256 pendingOracleVersion = self._pending.oracleVersion;
        require(pendingOracleVersion == 0 || pendingOracleVersion == oracleVersion, Errors.INVALID_ORACLE_VERSION);

        self._pending.tokenAmount += amount;
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

    function _settleMinting(
        LpSlotLiquidity storage self,
        uint256 pendingDeposit,
        uint256 slotValue,
        uint256 totalSupply,
        uint256 oracleVersion
    ) private returns (uint256 mintingAmount) {
        mintingAmount = calculateLpTokenMinting(pendingDeposit, slotValue, totalSupply);

        self.total += pendingDeposit;
        self._claimMintings[oracleVersion] = _ClaimMinting({tokenAmount: pendingDeposit, mintingAmount: mintingAmount});
    }

    function _settleBurning(
        LpSlotLiquidity storage self,
        uint256 pendingLpTokenAmount,
        uint256 freeLiquidity,
        uint256 slotValue,
        uint256 totalSupply,
        uint256 oracleVersion
    ) private returns (uint256 burningAmount, uint256 pendingWithdrawal) {
        pendingWithdrawal = calculateLpTokenValue(pendingLpTokenAmount, slotValue, totalSupply);
        if (freeLiquidity >= pendingWithdrawal) {
            burningAmount = pendingLpTokenAmount;
        } else {
            burningAmount = calculateLpTokenMinting(freeLiquidity, slotValue, totalSupply);
            require(burningAmount < pendingLpTokenAmount);
            pendingWithdrawal = freeLiquidity;
        }

        self.total -= pendingWithdrawal;
        self._burningVersions.pushBack(bytes32(oracleVersion));
        self._claimBurnings[oracleVersion] = _ClaimBurning({
            lpTokenAmount: pendingLpTokenAmount,
            burningAmount: burningAmount,
            tokenAmount: pendingWithdrawal
        });
    }
}
