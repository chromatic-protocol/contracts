// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {IUSUMRouter} from "@usum/periphery/interfaces/IUSUMRouter.sol";
import {VerifyCallback} from "@usum/periphery/base/VerifyCallback.sol";
import {AccountFactory} from "@usum/periphery/AccountFactory.sol";
import {Account} from "@usum/periphery/Account.sol";
import {LpTokenLib} from "@usum/core/libraries/LpTokenLib.sol";

contract USUMRouter is IUSUMRouter, VerifyCallback, Ownable {
    using SignedMath for int256;

    struct MintCallbackData {
        address payer;
        uint256 amount;
    }

    struct BurnCallbackData {
        address payer;
        uint256 tokenId;
        uint256 liquidity;
    }

    AccountFactory accountFactory;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "TradeRouter: EXPIRED");
        _;
    }

    function initialize(
        AccountFactory _accountFactory,
        address _marketFactory
    ) external onlyOwner {
        accountFactory = _accountFactory;
        marketFactory = _marketFactory;
    }

    function mintCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external verifyCallback {
        MintCallbackData memory callbackData = abi.decode(
            data,
            (MintCallbackData)
        );
        SafeERC20.safeTransferFrom(
            settlementToken,
            callbackData.payer,
            vault,
            callbackData.amount
        );
    }

    function burnCallback(
        address lpToken,
        bytes calldata data
    ) external verifyCallback {
        BurnCallbackData memory callbackData = abi.decode(
            data,
            (BurnCallbackData)
        );
        IERC1155(lpToken).safeTransferFrom(
            callbackData.payer,
            msg.sender,
            callbackData.tokenId,
            callbackData.liquidity,
            bytes("")
        );
    }

    function openPosition(
        address market,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee,
        uint256 deadline
    ) external ensure(deadline) returns (Position memory) {
        _getAccount(msg.sender).openPosition(
            market,
            qty,
            leverage,
            takerMargin,
            makerMargin,
            maxAllowableTradingFee
        );
    }

    function closePosition(
        address market,
        uint256 positionId,
        uint256 deadline
    ) external ensure(deadline) {
        _getAccount(msg.sender).closePosition(market, positionId);
    }

    function addLiquidity(
        address market,
        int16 feeRate,
        uint256 amount,
        address recipient,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 liquidity) {
    
        liquidity = IUSUMMarket(market).mint(
            recipient,
            feeRate,
            abi.encode(MintCallbackData({payer: msg.sender, amount: amount}))
        );
    }

    function removeLiquidity(
        address market,
        int16 feeRate,
        uint256 liquidity,
        uint256 amountMin,
        address recipient,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amount) {
    
        amount = IUSUMMarket(market).burn(
            recipient,
            feeRate,
            abi.encode(
                BurnCallbackData({
                    payer: msg.sender,
                    tokenId: LpTokenLib.encodeId(feeRate),
                    liquidity: liquidity
                })
            )
        );
        require(amount >= amountMin, "TradeRouter: insufficient amount");
    }

    function getAccount() external view returns (address) {
        return accountFactory.getAccount(msg.sender);
    }

    function _getAccount(address owner) internal view returns (Account) {
        return Account(accountFactory.getAccount(owner));
    }
}
