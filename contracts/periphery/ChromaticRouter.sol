// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarketFactory} from "@chromatic/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {Position} from "@chromatic/core/libraries/Position.sol";
import {LpReceipt} from "@chromatic/core/libraries/LpReceipt.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {IChromaticRouter} from "@chromatic/periphery/interfaces/IChromaticRouter.sol";
import {VerifyCallback} from "@chromatic/periphery/base/VerifyCallback.sol";
import {AccountFactory} from "@chromatic/periphery/AccountFactory.sol";
import {Account} from "@chromatic/periphery/Account.sol";
import {ICLBToken} from "@chromatic/core/interfaces/ICLBToken.sol";
import {CLBTokenLib} from "@chromatic/core/libraries/CLBTokenLib.sol";

contract ChromaticRouter is IChromaticRouter, VerifyCallback, Ownable {
    using SignedMath for int256;
    using EnumerableSet for EnumerableSet.UintSet;

    struct AddLiquidityCallbackData {
        address provider;
        uint256 amount;
    }

    struct ClaimLiquidityCallbackData {
        address provider;
    }

    struct RemoveLiquidityCallbackData {
        address provider;
        uint256 clbTokenAmount;
    }

    struct WithdrawLiquidityCallbackData {
        address provider;
    }

    AccountFactory accountFactory;
    mapping(address => mapping(address => EnumerableSet.UintSet)) private receiptIds; // market => provider => receiptIds

    error NotExistLpReceipt();

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
            callbackData.provider,
            vault,
            callbackData.amount
        );
    }

    function claimLiquidityCallback(
        uint256 receiptId,
        bytes calldata data
    ) external override verifyCallback {
        ClaimLiquidityCallbackData memory callbackData = abi.decode(
            data,
            (ClaimLiquidityCallbackData)
        );
        receiptIds[msg.sender][callbackData.provider].remove(receiptId);
    }

    function removeLiquidityCallback(
        address clbToken,
        uint256 clbTokenId,
        bytes calldata data
    ) external override verifyCallback {
        RemoveLiquidityCallbackData memory callbackData = abi.decode(
            data,
            (RemoveLiquidityCallbackData)
        );
        IERC1155(clbToken).safeTransferFrom(
            callbackData.provider,
            msg.sender, // market
            clbTokenId,
            callbackData.clbTokenAmount,
            bytes("")
        );
    }

    function withdrawLiquidityCallback(
        uint256 receiptId,
        bytes calldata data
    ) external override verifyCallback {
        WithdrawLiquidityCallbackData memory callbackData = abi.decode(
            data,
            (WithdrawLiquidityCallbackData)
        );
        receiptIds[msg.sender][callbackData.provider].remove(receiptId);
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
    ) public override returns (LpReceipt memory receipt) {
        bytes memory result = _call(
            market,
            abi.encodeWithSelector(
                IChromaticMarket(market).addLiquidity.selector,
                recipient,
                feeRate,
                abi.encode(AddLiquidityCallbackData({provider: msg.sender, amount: amount}))
            )
        );

        receipt = abi.decode(result, (LpReceipt));
        receiptIds[market][msg.sender].add(receipt.id);
    }

    function claimLiquidity(address market, uint256 receiptId) public override {
        address provider = msg.sender;
        if (!receiptIds[market][provider].contains(receiptId)) revert NotExistLpReceipt();

        _call(
            market,
            abi.encodeWithSelector(
                IChromaticMarket(market).claimLiquidity.selector,
                receiptId,
                abi.encode(ClaimLiquidityCallbackData({provider: provider}))
            )
        );
    }

    function removeLiquidity(
        address market,
        int16 feeRate,
        uint256 clbTokenAmount,
        address recipient
    ) public override returns (LpReceipt memory receipt) {
        bytes memory result = _call(
            market,
            abi.encodeWithSelector(
                IChromaticMarket(market).removeLiquidity.selector,
                recipient,
                feeRate,
                abi.encode(
                    RemoveLiquidityCallbackData({
                        provider: msg.sender,
                        clbTokenAmount: clbTokenAmount
                    })
                )
            )
        );

        receipt = abi.decode(result, (LpReceipt));
        receiptIds[market][msg.sender].add(receipt.id);
    }

    function withdrawLiquidity(address market, uint256 receiptId) public override {
        address provider = msg.sender;
        if (!receiptIds[market][provider].contains(receiptId)) revert NotExistLpReceipt();

        _call(
            market,
            abi.encodeWithSelector(
                IChromaticMarket(market).withdrawLiquidity.selector,
                receiptId,
                abi.encode(WithdrawLiquidityCallbackData({provider: provider}))
            )
        );
    }

    function getAccount() external view override returns (address) {
        return accountFactory.getAccount(msg.sender);
    }

    function _getAccount(address owner) internal view returns (Account) {
        return Account(accountFactory.getAccount(owner));
    }

    function getLpReceiptIds(address market) external view override returns (uint256[] memory) {
        return receiptIds[market][msg.sender].values();
    }

    function addLiquidityBatch(
        address market,
        int16[] calldata feeRates,
        uint256[] calldata amounts,
        address[] calldata recipients
    ) external override returns (LpReceipt[] memory lpReceipts) {
        require(
            feeRates.length == amounts.length && feeRates.length == recipients.length,
            "TradeRouter: invalid arguments"
        );
        lpReceipts = new LpReceipt[](feeRates.length);
        for (uint i = 0; i < feeRates.length; i++) {
            lpReceipts[i] = addLiquidity(market, feeRates[i], amounts[i], recipients[i]);
        }
    }

    function claimLiquidityBatch(address market, uint256[] calldata _receiptIds) external override {
        for (uint i = 0; i < _receiptIds.length; i++) {
            claimLiquidity(market, _receiptIds[i]);
        }
    }

    function removeLiquidityBatch(
        address market,
        int16[] calldata feeRates,
        uint256[] calldata clbTokenAmounts,
        address[] calldata recipients
    ) external override returns (LpReceipt[] memory lpReceipts) {
        require(
            feeRates.length == clbTokenAmounts.length && feeRates.length == recipients.length,
            "TradeRouter: invalid arguments"
        );
        lpReceipts = new LpReceipt[](feeRates.length);
        for (uint i = 0; i < feeRates.length; i++) {
            lpReceipts[i] = removeLiquidity(market, feeRates[i], clbTokenAmounts[i], recipients[i]);
        }
    }

    function withdrawLiquidityBatch(
        address market,
        uint256[] calldata _receiptIds
    ) external override {
        for (uint i = 0; i < _receiptIds.length; i++) {
            withdrawLiquidity(market, _receiptIds[i]);
        }
    }

    function _call(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory result) = target.call(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        return result;
    }

    
}
