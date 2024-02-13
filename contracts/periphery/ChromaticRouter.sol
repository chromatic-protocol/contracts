// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
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
import {OpenPositionInfo} from "@chromatic-protocol/contracts/core/interfaces/market/IMarketTradeOpenPosition.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

/**
 * @title ChromaticRouter
 * @dev A router contract that facilitates liquidity provision and trading on Chromatic.
 */
contract ChromaticRouter is AccountFactory, VerifyCallback {
    using Math for uint256;
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
     * @dev Struct representing the data for an addLiquidityBatch callback.
     * @param provider The address of the liquidity provider.
     * @param amount The amount of tokens being added as liquidity.
     */
    struct AddLiquidityBatchCallbackData {
        address provider;
        uint256 amount;
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
     * @dev Struct representing the data for a removeLiquidityBatch callback.
     * @param provider The address of the liquidity provider.
     * @param clbTokenAmounts An array of CLB token amounts being removed.
     */
    struct RemoveLiquidityBatchCallbackData {
        address provider;
        uint256[] clbTokenAmounts;
    }

    mapping(address => mapping(uint256 => address)) providerMap; // market => receiptId => provider
    mapping(address => mapping(address => EnumerableSet.UintSet)) receiptIds; // market => provider => receiptIds

    /**
     * @dev Initializes the ChromaticRouter contract.
     * @param _marketFactory The address of the ChromaticMarketFactory contract.
     */
    constructor(address _marketFactory) AccountFactory(_marketFactory) {
        require(_marketFactory != address(0));
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
        //slither-disable-next-line arbitrary-send-erc20
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
    function addLiquidityBatchCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external override verifyCallback {
        AddLiquidityBatchCallbackData memory callbackData = abi.decode(
            data,
            (AddLiquidityBatchCallbackData)
        );
        //slither-disable-next-line arbitrary-send-erc20
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
        int16,
        uint256,
        uint256,
        bytes calldata
    ) external override verifyCallback {
        // address market = msg.sender; // save gas : MSTORE,MLOAD - 3, CALLER(msg.sender) - 2
        address provider = providerMap[msg.sender][receiptId];

        //slither-disable-next-line unused-return
        receiptIds[msg.sender][provider].remove(receiptId);
        delete providerMap[msg.sender][receiptId];
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     */
    function claimLiquidityBatchCallback(
        uint256[] calldata _receiptIds,
        int16[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external override verifyCallback {
        // address market = msg.sender; // save gas : MSTORE,MLOAD - 3, CALLER(msg.sender) - 2
        for (uint256 i; i < _receiptIds.length; ) {
            uint256 receiptId = _receiptIds[i];
            address provider = providerMap[msg.sender][receiptId];

            //slither-disable-next-line unused-return
            receiptIds[msg.sender][provider].remove(_receiptIds[i]);
            delete providerMap[msg.sender][receiptId];

            unchecked {
                ++i;
            }
        }
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
    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata clbTokenIds,
        bytes calldata data
    ) external override verifyCallback {
        RemoveLiquidityBatchCallbackData memory callbackData = abi.decode(
            data,
            (RemoveLiquidityBatchCallbackData)
        );

        IERC1155(clbToken).safeBatchTransferFrom(
            callbackData.provider,
            msg.sender, // market
            clbTokenIds,
            callbackData.clbTokenAmounts,
            bytes("")
        );
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     */
    function withdrawLiquidityCallback(
        uint256 receiptId,
        int16,
        uint256,
        uint256,
        bytes calldata
    ) external override verifyCallback {
        // address market = msg.sender; // save gas : MSTORE,MLOAD - 3, CALLER(msg.sender) - 2
        address provider = providerMap[msg.sender][receiptId];

        //slither-disable-next-line unused-return
        receiptIds[msg.sender][provider].remove(receiptId);
        delete providerMap[msg.sender][receiptId];
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     */
    function withdrawLiquidityBatchCallback(
        uint256[] calldata _receiptIds,
        int16[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external override verifyCallback {
        // address market = msg.sender; // save gas : MSTORE,MLOAD - 3, CALLER(msg.sender) - 2
        for (uint256 i; i < _receiptIds.length; ) {
            uint256 receiptId = _receiptIds[i];
            address provider = providerMap[msg.sender][receiptId];

            //slither-disable-next-line unused-return
            receiptIds[msg.sender][provider].remove(_receiptIds[i]);
            delete providerMap[msg.sender][receiptId];

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function openPosition(
        address market,
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) external override returns (OpenPositionInfo memory) {
        return _openPosition(market, qty, takerMargin, makerMargin, maxAllowableTradingFee);
    }

    function _openPosition(
        address market,
        int256 qty,
        uint256 takerMargin,
        uint256 makerMargin,
        uint256 maxAllowableTradingFee
    ) internal returns (OpenPositionInfo memory openPositionInfo) {
        ChromaticAccount account = _getAccount(msg.sender);
        openPositionInfo = account.openPosition(
            market,
            qty,
            takerMargin,
            makerMargin,
            maxAllowableTradingFee
        );

        //slither-disable-next-line reentrancy-events
        emit OpenPosition(
            market,
            msg.sender,
            address(account),
            openPositionInfo.tradingFee,
            _calcUsdPrice(market, openPositionInfo.tradingFee)
        );
    }

    /**
     * @dev Calculates the price in USD for a specified amount of the settlement token in a ChromaticMarket.
     * @param market The address of the ChromaticMarket contract.
     * @param amount The amount of the settlement token.
     * @return The price in USD as an int256.
     */
    function _calcUsdPrice(address market, uint256 amount) internal view returns (uint256) {
        IERC20Metadata settlementToken = IChromaticMarket(market).settlementToken();

        IOracleProvider oracleProvider = IOracleProvider(
            IChromaticMarketFactory(marketFactory).getSettlementTokenOracleProvider(
                address(settlementToken)
            )
        );

        int256 latestPrice = oracleProvider.currentVersion().price;

        uint256 unsignedLatestPrice = uint256(latestPrice.max(0));

        // token amount * oracle price / token decimals
        return amount.mulDiv(unsignedLatestPrice, 10 ** settlementToken.decimals());
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
    ) external override returns (LpReceipt memory receipt) {
        // address provider = msg.sender; // save gas : MSTORE,MLOAD - 3, CALLER(msg.sender) - 2
        providerMap[market][receipt.id] = msg.sender;
        receipt = IChromaticMarket(market).addLiquidity(
            recipient,
            feeRate,
            abi.encode(AddLiquidityCallbackData({provider: msg.sender, amount: amount}))
        );

        //slither-disable-next-line unused-return
        receiptIds[market][msg.sender].add(receipt.id);
    }

    /**
     * @inheritdoc IChromaticRouter
     * @dev This function allows the liquidity provider to claim their liquidity by calling the `claimLiquidity` function in the specified market contract.
     */
    function claimLiquidity(address market, uint256 receiptId) external override {
        IChromaticMarket(market).claimLiquidity(receiptId, bytes(""));
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function removeLiquidity(
        address market,
        int16 feeRate,
        uint256 clbTokenAmount,
        address recipient
    ) external override returns (LpReceipt memory receipt) {
        // address provider = msg.sender; // save gas : MSTORE,MLOAD - 3, CALLER(msg.sender) - 2
        providerMap[market][receipt.id] = msg.sender;
        receipt = IChromaticMarket(market).removeLiquidity(
            recipient,
            feeRate,
            abi.encode(
                RemoveLiquidityCallbackData({provider: msg.sender, clbTokenAmount: clbTokenAmount})
            )
        );

        //slither-disable-next-line unused-return
        receiptIds[market][msg.sender].add(receipt.id);
    }

    /**
     * @inheritdoc IChromaticRouter
     * @dev This function allows the liquidity provider to withdraw their liquidity by calling the `withdrawLiquidity` function in the specified market contract.
     */
    function withdrawLiquidity(address market, uint256 receiptId) external override {
        IChromaticMarket(market).withdrawLiquidity(receiptId, bytes(""));
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
        address recipient,
        int16[] calldata feeRates,
        uint256[] calldata amounts
    ) external override returns (LpReceipt[] memory lpReceipts) {
        require(feeRates.length == amounts.length, "TradeRouter: invalid arguments");

        uint256 totalAmount;
        for (uint256 i; i < amounts.length; ) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        // address provider = msg.sender; // save gas : MSTORE,MLOAD - 3, CALLER(msg.sender) - 2
        lpReceipts = IChromaticMarket(market).addLiquidityBatch(
            recipient,
            feeRates,
            amounts,
            abi.encode(AddLiquidityBatchCallbackData({provider: msg.sender, amount: totalAmount}))
        );

        for (uint i; i < feeRates.length; ) {
            uint256 receiptId = lpReceipts[i].id;
            //slither-disable-next-line unused-return
            receiptIds[market][msg.sender].add(receiptId);
            //slither-disable-next-line reentrancy-benign
            providerMap[market][receiptId] = msg.sender;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function claimLiquidityBatch(address market, uint256[] calldata _receiptIds) external override {
        IChromaticMarket(market).claimLiquidityBatch(_receiptIds, bytes(""));
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function removeLiquidityBatch(
        address market,
        address recipient,
        int16[] calldata feeRates,
        uint256[] calldata clbTokenAmounts
    ) external override returns (LpReceipt[] memory lpReceipts) {
        require(feeRates.length == clbTokenAmounts.length, "TradeRouter: invalid arguments");

        // address provider = msg.sender; // save gas : MSTORE,MLOAD - 3, CALLER(msg.sender) - 2
        lpReceipts = IChromaticMarket(market).removeLiquidityBatch(
            recipient,
            feeRates,
            clbTokenAmounts,
            abi.encode(
                RemoveLiquidityBatchCallbackData({
                    provider: msg.sender,
                    clbTokenAmounts: clbTokenAmounts
                })
            )
        );

        for (uint i; i < feeRates.length; ) {
            uint256 receiptId = lpReceipts[i].id;
            //slither-disable-next-line unused-return
            receiptIds[market][msg.sender].add(receiptId);
            //slither-disable-next-line reentrancy-benign
            providerMap[market][receiptId] = msg.sender;

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @inheritdoc IChromaticRouter
     */
    function withdrawLiquidityBatch(
        address market,
        uint256[] calldata _receiptIds
    ) external override {
        IChromaticMarket(market).withdrawLiquidityBatch(_receiptIds, bytes(""));
    }
}
