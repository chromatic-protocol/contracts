// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";

import {IUSUMRouter} from "@usum/periphery/interfaces/IUSUMRouter.sol";
import {VerifyCallback} from "@usum/periphery/base/VerifyCallback.sol";
import {AccountFactory} from "./AccountFactory.sol";
import {Account} from "./Account.sol";

contract USUMRouter is IUSUMRouter, VerifyCallback, Ownable {
    using SignedMath for int256;

    struct MintCallbackData {
        address payer;
        uint256 amount;
    }

    struct BurnCallbackData {
        address payer;
        uint256 liquidity;
    }

    AccountFactory accountFactory;
    IUSUMMarketFactory marketFactory;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "TradeRouter: EXPIRED");
        _;
    }

    function initalize(
        AccountFactory _accountFactory,
        IUSUMMarketFactory _marketFactory
    ) external onlyOwner {
        accountFactory = _accountFactory;
        marketFactory = _marketFactory;
    }

    function mintCallback(
        address settlementToken,
        bytes calldata data
    ) external verifyCallback {
        MintCallbackData memory callbackData = abi.decode(
            data,
            (MintCallbackData)
        );
        SafeERC20.safeTransferFrom(
            settlementToken,
            callbackData.payer,
            msg.sender,
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
        SafeERC20.safeTransferFrom(
            lpToken,
            callbackData.payer,
            msg.sender,
            callbackData.liquidity
        );
    }

    function openPosition(
        address oracleProvider,
        address settlementToken,
        uint256 takerMargin,
        uint256 makerMargin,
        int256 qty,
        uint32 leverage,
        uint256 deadline
    ) external ensure(deadline) {
        address market = marketFactory.getMarket(
            oracleProvider,
            settlementToken
        );
        _getAccount(msg.sender).openPosition(
            market,
            qty,
            leverage,
            takerMargin,
            makerMargin
        );
    }

    function closePosition(
        address oracleProvider,
        address settlementToken,
        uint256 positionId,
        uint256 deadline
    ) external ensure(deadline) {
        address market = marketFactory.getMarket(
            oracleProvider,
            settlementToken
        );
        _getAccount(msg.sender).closePosition(market, positionId);
    }

    function addLiquidity(
        address oracleProvider,
        address settlementToken,
        int16 feeRate,
        uint256 amount,
        address recipient,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 liquidity) {
        address market = marketFactory.getMarket(
            oracleProvider,
            settlementToken
        );
        _prepareMarket(address(market));
        liquidity = IUSUMMarket(market).mint(
            recipient,
            feeRate,
            abi.encode(MintCallbackData({payer: msg.sender, amount: amount}))
        );
    }

    function removeLiquidity(
        address oracleProvider,
        address settlementToken,
        int16 feeRate,
        uint256 liquidity,
        uint256 amountMin,
        address recipient,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amount) {
        address market = marketFactory.getMarket(
            oracleProvider,
            settlementToken
        );
        _prepareMarket(address(market));
        amount = IUSUMMarket(market).burn(
            recipient,
            feeRate,
            abi.encode(
                BurnCallbackData({payer: msg.sender, liquidity: liquidity})
            )
        );
        require(amount >= amountMin, "TradeRouter: insufficient amount");
    }

    function _getAccount(address owner) internal view returns (Account) {
        return Account(accountFactory.getAccount(owner));
    }
}
