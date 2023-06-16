// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";

import {IChromaticRouter} from "@chromatic-protocol/contracts/periphery/interfaces/IChromaticRouter.sol";
import {AccountFactory} from "@chromatic-protocol/contracts/periphery/base/AccountFactory.sol";
import {VerifyCallback} from "@chromatic-protocol/contracts/periphery/base/VerifyCallback.sol";
import {ChromaticAccount} from "@chromatic-protocol/contracts/periphery/ChromaticAccount.sol";

/**
 * @title ChromaticRouter
 * @dev A router contract that facilitates liquidity provision and trading on Chromatic.
 */
contract ChromaticRouter is AccountFactory, VerifyCallback, Ownable {
    using SignedMath for int256;
    using EnumerableSet for EnumerableSet.UintSet;

    /**
     * @dev Struct representing the data for an addLiquidity callback.
     * @param provider The address of the liquidity provider.
     * @param amount The amount of tokens being added as liquidity.
     */
    struct AddLiquidityCallbackData {
        address provider;
        uint256 amount;
    }

    /**
     * @dev Struct representing the data for a claimLiquidity callback.
     * @param provider The address of the liquidity provider.
     */
    struct ClaimLiquidityCallbackData {
        address provider;
    }

    /**
     * @dev Struct representing the data for a removeLiquidity callback.
     * @param provider The address of the liquidity provider.
     * @param clbTokenAmount The amount of CLB tokens being removed.
     */
    struct RemoveLiquidityCallbackData {
        address provider;
        uint256 clbTokenAmount;
    }

    /**
     * @dev Struct representing the data for a withdrawLiquidity callback.
     * @param provider The address of the liquidity provider.
     */
    struct WithdrawLiquidityCallbackData {
        address provider;
    }

    mapping(address => mapping(address => EnumerableSet.UintSet)) private receiptIds; // market => provider => receiptIds

    error NotExistLpReceipt();

    /**
     * @dev Initializes the ChromaticRouter contract.
     * @param _marketFactory The address of the ChromaticMarketFactory contract.
     */
    constructor(address _marketFactory) onlyOwner AccountFactory(_marketFactory) {
        marketFactory = _marketFactory;
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     */
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

    /**
     * @inheritdoc IChromaticLiquidityCallback
     */
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

    /**
     * @inheritdoc IChromaticLiquidityCallback
     */
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

    /**
     * @inheritdoc IChromaticLiquidityCallback
     */
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

    /**
     * @inheritdoc IChromaticRouter
     */
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

    /**
     * @inheritdoc IChromaticRouter
     */
    function closePosition(address market, uint256 positionId) external override {
        _getAccount(msg.sender).closePosition(market, positionId);
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function claimPosition(address market, uint256 positionId) external override {
        _getAccount(msg.sender).claimPosition(market, positionId);
    }

    /**
     * @inheritdoc IChromaticRouter
     */
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

    /**
     * @inheritdoc IChromaticRouter
     */
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

    /**
     * @inheritdoc IChromaticRouter
     */
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

    /**
     * @inheritdoc IChromaticRouter
     */
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

    /**
     * @dev Retrieves the account of the specified owner.
     * @param owner The owner of the account.
     * @return The account address.
     */
    function _getAccount(address owner) internal view returns (ChromaticAccount) {
        return ChromaticAccount(getAccount(owner));
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function getLpReceiptIds(address market) external view override returns (uint256[] memory) {
        return getLpReceiptIds(market, msg.sender);
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function getLpReceiptIds(
        address market,
        address owner
    ) public view override returns (uint256[] memory) {
        return receiptIds[market][owner].values();
    }

    /**
     * @inheritdoc IChromaticRouter
     */
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

    /**
     * @inheritdoc IChromaticRouter
     */
    function claimLiquidityBatch(address market, uint256[] calldata _receiptIds) external override {
        for (uint i = 0; i < _receiptIds.length; i++) {
            claimLiquidity(market, _receiptIds[i]);
        }
    }

    /**
     * @inheritdoc IChromaticRouter
     */
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

    /**
     * @inheritdoc IChromaticRouter
     */
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
