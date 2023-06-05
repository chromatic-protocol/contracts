// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import {IOracleProvider} from "@chromatic/core/interfaces/IOracleProvider.sol";
import {ICLBToken} from "@chromatic/core/interfaces/ICLBToken.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {Errors} from "@chromatic/core/libraries/Errors.sol";

/**
 * @title LpSlotLiquidity
 * @notice Represents the liquidity information within an LpSlot.
 */
struct LpSlotLiquidity {
    uint256 total;
    _PendingLiquidity _pending;
    mapping(uint256 => _ClaimMinting) _claimMintings;
    mapping(uint256 => _ClaimBurning) _claimBurnings;
    DoubleEndedQueue.Bytes32Deque _burningVersions;
}

/**
 * @title _PendingLiquidity
 * @notice Represents the pending liquidity details within LpSlotLiquidity.
 */
struct _PendingLiquidity {
    uint256 oracleVersion;
    uint256 tokenAmount;
    uint256 clbTokenAmount;
}

/**
 * @title _ClaimMinting
 * @notice Represents the accumulated values of minting claims
 *         for a specific oracle version within LpSlotLiquidity.
 */
struct _ClaimMinting {
    uint256 tokenAmount;
    uint256 mintingAmount;
}

/**
 * @title _ClaimBurning
 * @notice Represents the accumulated values of burning claims
 *         for a specific oracle version within LpSlotLiquidity.
 */
struct _ClaimBurning {
    uint256 clbTokenAmount;
    uint256 burningAmount;
    uint256 tokenAmount;
}

/**
 * @title LpSlotLiquidityLib
 * @notice A library that provides functions to manage the liquidity within an LpSlot.
 */
library LpSlotLiquidityLib {
    using Math for uint256;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    /// @dev Minimum amount constant to prevent division by zero.
    uint256 private constant MIN_AMOUNT = 1000;

    /**
     * @notice Settles the pending liquidity within the LpSlotLiquidity.
     * @dev If the pending oracle version is not set or is greater than or equal to the current oracle version, no action is taken.
     *      Otherwise, the pending liquidity and burning CLB tokens are settled by following steps:
     *          1. Settles pending liquidity
     *              a. If there is a pending deposit,
     *                 it calculates the minting amount of CLB tokens
     *                 based on the pending deposit, slot value, and CLB token total supply.
     *                 It updates the total liquidity and adds the pending deposit to the claim mintings.
     *              b. If there is a pending CLB token burning,
     *                 it adds the oracle version to the burning versions list
     *                 and initializes the claim burning details.
     *          2. Settles bunding CLB tokens
     *              a. It trims all completed burning versions from the burning versions list.
     *              b. For each burning version in the list,
     *                 it calculates the pending CLB token amount and the pending withdrawal amount
     *                 based on the slot value and CLB token total supply.
     *                 - If there is sufficient free liquidity, it calculates the burning amount of CLB tokens.
     *                 - If there is insufficient free liquidity, it calculates the burning amount
     *                   based on the available free liquidity and updates the pending withdrawal accordingly.
     *              c. It updates the burning amount and pending withdrawal,
     *                 and reduces the free liquidity accordingly.
     *              d. Finally, it updates the total liquidity by subtracting the pending withdrawal.
     *      And the CLB tokens are minted or burned accordingly.
     *      The pending deposit and withdrawal amounts are passed to the vault for further processing.
     * @param self The LpSlotLiquidity storage.
     * @param ctx The LpContext memory.
     * @param slotValue The current value of the slot.
     * @param freeLiquidity The amount of free liquidity available in the slot.
     * @param clbTokenId The ID of the CLB token.
     */
    function settlePendingLiquidity(
        LpSlotLiquidity storage self,
        LpContext memory ctx,
        uint256 slotValue,
        uint256 freeLiquidity,
        uint256 clbTokenId
    ) internal {
        uint256 oracleVersion = self._pending.oracleVersion;
        if (oracleVersion == 0) return;

        IOracleProvider.OracleVersion memory currentVersion = ctx.currentOracleVersion();
        if (oracleVersion >= currentVersion.version) return;

        ICLBToken clbToken = ctx.clbToken;
        uint256 totalSupply = clbToken.totalSupply(clbTokenId);

        uint256 pendingDeposit = self._pending.tokenAmount;
        uint256 pendingCLBTokenAmount = self._pending.clbTokenAmount;

        uint256 mintingAmount = _settlePending(
            self,
            pendingDeposit,
            pendingCLBTokenAmount,
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
            clbToken.mint(ctx.market, clbTokenId, mintingAmount - burningAmount, bytes(""));
        } else if (mintingAmount < burningAmount) {
            clbToken.burn(ctx.market, clbTokenId, burningAmount - mintingAmount);
        }

        ctx.vault.onSettlePendingLiquidity(pendingDeposit, pendingWithdrawal);

        delete self._pending;
    }

    /**
     * @notice Adds liquidity to the LpSlotLiquidity.
     * @dev Sets the pending liquidity with the specified amount and oracle version.
     *      If the amount is less than the minimum amount, it reverts with an error.
     *      If there is already pending liquidity with a different oracle version, it reverts with an error.
     * @param self The LpSlotLiquidity storage.
     * @param amount The amount of tokens to add for liquidity.
     * @param oracleVersion The oracle version associated with the liquidity.
     */
    function onAddLiquidity(
        LpSlotLiquidity storage self,
        uint256 amount,
        uint256 oracleVersion
    ) internal {
        require(amount > MIN_AMOUNT, Errors.TOO_SMALL_AMOUNT);

        uint256 pendingOracleVersion = self._pending.oracleVersion;
        require(
            pendingOracleVersion == 0 || pendingOracleVersion == oracleVersion,
            Errors.INVALID_ORACLE_VERSION
        );

        self._pending.oracleVersion = oracleVersion;
        self._pending.tokenAmount += amount;
    }

    /**
     * @notice Claims liquidity from the LpSlotLiquidity by minting CLB tokens.
     * @dev Retrieves the minting details for the specified oracle version
     *      and calculates the CLB token amount to be claimed.
     *      Updates the claim minting details and returns the CLB token amount to be claimed.
     *      If there are no more tokens remaining for the claim, it is removed from the mapping.
     * @param self The LpSlotLiquidity storage.
     * @param amount The amount of tokens to claim.
     * @param oracleVersion The oracle version associated with the claim.
     * @return clbTokenAmount The amount of CLB tokens to be claimed.
     */
    function onClaimLiquidity(
        LpSlotLiquidity storage self,
        uint256 amount,
        uint256 oracleVersion
    ) internal returns (uint256 clbTokenAmount) {
        _ClaimMinting memory _cm = self._claimMintings[oracleVersion];
        clbTokenAmount = amount.mulDiv(_cm.mintingAmount, _cm.tokenAmount);

        _cm.mintingAmount -= clbTokenAmount;
        _cm.tokenAmount -= amount;
        if (_cm.tokenAmount == 0) {
            delete self._claimMintings[oracleVersion];
        } else {
            self._claimMintings[oracleVersion] = _cm;
        }
    }

    /**
     * @notice Removes liquidity from the LpSlotLiquidity by setting pending CLB token amount.
     * @dev Sets the pending liquidity with the specified CLB token amount and oracle version.
     *      If there is already pending liquidity with a different oracle version, it reverts with an error.
     * @param self The LpSlotLiquidity storage.
     * @param clbTokenAmount The amount of CLB tokens to remove liquidity.
     * @param oracleVersion The oracle version associated with the liquidity.
     */
    function onRemoveLiquidity(
        LpSlotLiquidity storage self,
        uint256 clbTokenAmount,
        uint256 oracleVersion
    ) internal {
        uint256 pendingOracleVersion = self._pending.oracleVersion;
        require(
            pendingOracleVersion == 0 || pendingOracleVersion == oracleVersion,
            Errors.INVALID_ORACLE_VERSION
        );

        self._pending.oracleVersion = oracleVersion;
        self._pending.clbTokenAmount += clbTokenAmount;
    }

    /**
     * @notice Withdraws liquidity from the LpSlotLiquidity by burning CLB tokens and withdrawing tokens.
     * @dev Retrieves the burning details for the specified oracle version
     *      and calculates the CLB token amount and token amount to burn and withdraw, respectively.
     *      Updates the claim burning details and returns the token amount to withdraw and the burned CLB token amount.
     *      If there are no more CLB tokens remaining for the claim, it is removed from the mapping.
     * @param self The LpSlotLiquidity storage.
     * @param clbTokenAmount The amount of CLB tokens to withdraw.
     * @param oracleVersion The oracle version associated with the claim.
     * @return amount The amount of tokens to be withdrawn for the claim.
     * @return burnedCLBTokenAmount The amount of CLB tokens to be burned for the claim.
     */
    function onWithdrawLiquidity(
        LpSlotLiquidity storage self,
        uint256 clbTokenAmount,
        uint256 oracleVersion
    ) internal returns (uint256 amount, uint256 burnedCLBTokenAmount) {
        _ClaimBurning memory _cb = self._claimBurnings[oracleVersion];
        amount = clbTokenAmount.mulDiv(_cb.tokenAmount, _cb.clbTokenAmount);
        burnedCLBTokenAmount = clbTokenAmount.mulDiv(_cb.burningAmount, _cb.clbTokenAmount);

        _cb.burningAmount -= burnedCLBTokenAmount;
        _cb.tokenAmount -= amount;
        _cb.clbTokenAmount -= clbTokenAmount;
        if (_cb.clbTokenAmount == 0) {
            delete self._claimBurnings[oracleVersion];
        } else {
            self._claimBurnings[oracleVersion] = _cb;
        }
    }

    /**
     * @notice Calculates the amount of CLB tokens to be minted
     *         for a given token amount, slot value, and CLB token total supply.
     * @dev If the CLB token total supply is zero, returns the token amount as is.
     *      Otherwise, calculates the minting amount
     *      based on the token amount, slot value, and CLB token total supply.
     * @param amount The amount of tokens to be minted.
     * @param slotValue The current slot value.
     * @param clbTokenTotalSupply The total supply of CLB tokens.
     * @return The amount of CLB tokens to be minted.
     */
    function calculateCLBTokenMinting(
        uint256 amount,
        uint256 slotValue,
        uint256 clbTokenTotalSupply
    ) internal pure returns (uint256) {
        return
            clbTokenTotalSupply == 0
                ? amount
                : amount.mulDiv(
                    clbTokenTotalSupply,
                    slotValue < MIN_AMOUNT ? MIN_AMOUNT : slotValue
                );
    }

    /**
     * @notice Calculates the value of CLB tokens
     *         for a given CLB token amount, slot value, and CLB token total supply.
     * @dev If the CLB token total supply is zero, returns zero.
     *      Otherwise, calculates the value based on the CLB token amount, slot value, and CLB token total supply.
     * @param clbTokenAmount The amount of CLB tokens.
     * @param slotValue The current slot value.
     * @param clbTokenTotalSupply The total supply of CLB tokens.
     * @return The value of the CLB tokens.
     */
    function calculateCLBTokenValue(
        uint256 clbTokenAmount,
        uint256 slotValue,
        uint256 clbTokenTotalSupply
    ) internal pure returns (uint256) {
        return clbTokenTotalSupply == 0 ? 0 : clbTokenAmount.mulDiv(slotValue, clbTokenTotalSupply);
    }

    /**
     * @dev Settles the pending deposit and pending CLB token burning.
     * @param self The LpSlotLiquidity storage.
     * @param pendingDeposit The amount of pending deposit to settle.
     * @param pendingCLBTokenAmount The amount of pending CLB tokens to burn.
     * @param slotValue The current value of the slot.
     * @param totalSupply The total supply of CLB tokens.
     * @param oracleVersion The oracle version associated with the pending deposit and CLB token burning.
     * @return mintingAmount The calculated minting amount of CLB tokens for the pending deposit.
     */
    function _settlePending(
        LpSlotLiquidity storage self,
        uint256 pendingDeposit,
        uint256 pendingCLBTokenAmount,
        uint256 slotValue,
        uint256 totalSupply,
        uint256 oracleVersion
    ) private returns (uint256 mintingAmount) {
        if (pendingDeposit > 0) {
            mintingAmount = calculateCLBTokenMinting(pendingDeposit, slotValue, totalSupply);

            self.total += pendingDeposit;
            self._claimMintings[oracleVersion] = _ClaimMinting({
                tokenAmount: pendingDeposit,
                mintingAmount: mintingAmount
            });
        }

        if (pendingCLBTokenAmount > 0) {
            self._burningVersions.pushBack(bytes32(oracleVersion));
            self._claimBurnings[oracleVersion] = _ClaimBurning({
                clbTokenAmount: pendingCLBTokenAmount,
                burningAmount: 0,
                tokenAmount: 0
            });
        }
    }

    /**
     * @dev Settles the pending CLB token burning and calculates the burning amount and pending withdrawal.
     * @param self The LpSlotLiquidity storage.
     * @param freeLiquidity The amount of free liquidity available for burning.
     * @param slotValue The current value of the slot.
     * @param totalSupply The total supply of CLB tokens.
     * @return burningAmount The calculated burning amount of CLB tokens.
     * @return pendingWithdrawal The calculated pending withdrawal amount.
     */
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
            if (_cb.burningAmount >= _cb.clbTokenAmount) {
                self._burningVersions.popFront();
                if (_cb.clbTokenAmount == 0) {
                    delete self._claimBurnings[_ov];
                }
            } else {
                break;
            }
        }

        uint256 length = self._burningVersions.length();
        for (uint256 i = 0; i < length && freeLiquidity > 0; i++) {
            uint256 _ov = uint256(self._burningVersions.at(i));
            _ClaimBurning storage _cb = self._claimBurnings[_ov];

            uint256 _pendingCLBTokenAmount = _cb.clbTokenAmount - _cb.burningAmount;
            if (_pendingCLBTokenAmount > 0) {
                uint256 _burningAmount;
                uint256 _pendingWithdrawal = calculateCLBTokenValue(
                    _pendingCLBTokenAmount,
                    slotValue,
                    totalSupply
                );
                if (freeLiquidity >= _pendingWithdrawal) {
                    _burningAmount = _pendingCLBTokenAmount;
                } else {
                    _burningAmount = calculateCLBTokenMinting(freeLiquidity, slotValue, totalSupply);
                    require(_burningAmount < _pendingCLBTokenAmount);
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
