// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IUSUMMarketFactory} from "@usum/core/interfaces/IUSUMMarketFactory.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {LpReceipt} from "@usum/core/libraries/LpReceipt.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {IUSUMRouter} from "@usum/periphery/interfaces/IUSUMRouter.sol";
import {VerifyCallback} from "@usum/periphery/base/VerifyCallback.sol";
import {AccountFactory} from "@usum/periphery/AccountFactory.sol";
import {Account} from "@usum/periphery/Account.sol";
import {LpTokenLib} from "@usum/core/libraries/LpTokenLib.sol";

contract USUMRouter is IUSUMRouter, VerifyCallback, Ownable {
    using SignedMath for int256;
    using EnumerableSet for EnumerableSet.UintSet;

    struct AddLiquidityCallbackData {
        address payer;
        uint256 amount;
    }

    struct BurnCallbackData {
        address payer;
        uint256 tokenId;
        uint256 lpTokenAmount;
    }

    AccountFactory accountFactory;
    mapping(address => mapping(address => EnumerableSet.UintSet)) private receiptIds; // market => recipient => receiptIds

    function initialize(AccountFactory _accountFactory, address _marketFactory) external onlyOwner {
        accountFactory = _accountFactory;
        marketFactory = _marketFactory;
    }

    function addLiquidityCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external override verifyCallback {
        AddLiquidityCallbackData memory callbackData = abi.decode(data, (AddLiquidityCallbackData));
        SafeERC20.safeTransferFrom(
            IERC20(settlementToken),
            callbackData.payer,
            vault,
            callbackData.amount
        );
    }

    function claimLpTokenCallback(
        uint256 receiptId,
        address recipient,
        bytes calldata data
    ) external override verifyCallback {
        receiptIds[msg.sender][recipient].remove(receiptId);
    }

    function removeLiquidityCallback(
        address lpToken,
        bytes calldata data
    ) external override verifyCallback {
        BurnCallbackData memory callbackData = abi.decode(data, (BurnCallbackData));
        IERC1155(lpToken).safeTransferFrom(
            callbackData.payer,
            msg.sender, // market
            callbackData.tokenId,
            callbackData.lpTokenAmount,
            bytes("")
        );
    }

    function openPosition(
        address market,
        int224 qty,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external override returns (Position memory) {
        return
            _getAccount(msg.sender).openPosition(
                market,
                qty,
                leverage,
                takerMargin,
                makerMargin,
                maxAllowableTradingFee
            );
    }

    function closePosition(address market, uint256 positionId) external override {
        _getAccount(msg.sender).closePosition(market, positionId);
    }

    function claimPosition(address market, uint256 positionId) external override {
        _getAccount(msg.sender).claimPosition(market, positionId);
    }

    function addLiquidity(
        address market,
        int16 feeRate,
        uint256 amount,
        address recipient
    ) external override returns (LpReceipt memory receipt) {
        receipt = IUSUMMarket(market).addLiquidity(
            recipient,
            feeRate,
            abi.encode(AddLiquidityCallbackData({payer: msg.sender, amount: amount}))
        );
        receiptIds[market][recipient].add(receipt.id);
    }

    function claimLpToken(address market, uint256 receiptId) external override {
        IUSUMMarket(market).claimLpToken(receiptId, bytes(""));
    }

    function removeLiquidity(
        address market,
        int16 feeRate,
        uint256 lpTokenAmount,
        uint256 amountMin,
        address recipient
    ) external override returns (uint256 amount) {
        amount = IUSUMMarket(market).removeLiquidity(
            recipient,
            feeRate,
            abi.encode(
                BurnCallbackData({
                    payer: msg.sender,
                    tokenId: LpTokenLib.encodeId(feeRate),
                    lpTokenAmount: lpTokenAmount
                })
            )
        );
        require(amount >= amountMin, "TradeRouter: insufficient amount");
    }

    function getAccount() external view override returns (address) {
        return accountFactory.getAccount(msg.sender);
    }

    function _getAccount(address owner) internal view returns (Account) {
        return Account(accountFactory.getAccount(owner));
    }
}
