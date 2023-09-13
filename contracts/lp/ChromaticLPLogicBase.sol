// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {CLBTokenLib} from "@chromatic-protocol/contracts/core/libraries/CLBTokenLib.sol";
import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";
import {AutomateReady} from "@chromatic-protocol/contracts/core/base/gelato/AutomateReady.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {IChromaticMarketFactory} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarketFactory.sol";
import {IKeeperFeePayer} from "@chromatic-protocol/contracts/core/interfaces/IKeeperFeePayer.sol";
import {ChromaticLPStorage} from "@chromatic-protocol/contracts/lp/ChromaticLPStorage.sol";
import {ValueInfo} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLPLens.sol";

abstract contract ChromaticLPLogicBase is ChromaticLPStorage {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    error InvalidUtilizationTarget(uint16 targetBPS);
    error InvalidRebalanceBPS();
    error NotMatchDistributionLength(uint256 feeLength, uint256 distributionLength);
    error InvalidDistributionSum();

    error NotMarket();
    error OnlyBatchCall();

    error UnknownLPAction();
    error NotOwner();
    error AlreadySwapRouterConfigured();
    error NotKeeperCalled();

    struct AddLiquidityBatchCallbackData {
        address provider;
        uint256 liquidityAmount;
        uint256 holdingAmount;
    }

    struct RemoveLiquidityBatchCallbackData {
        address provider;
        uint256 lpTokenAmount;
        uint256[] clbTokenAmounts;
    }

    modifier verifyCallback() virtual {
        if (address(s_config.market) != msg.sender) revert NotMarket();
        _;
    }
    modifier onlyKeeper() virtual {
        if (msg.sender != dedicatedMsgSender) revert NotKeeperCalled();
        _;
    }

    constructor(AutomateParam memory automateParam) ChromaticLPStorage(automateParam) {}

    function nextReceiptId() internal returns (uint256 id) {
        id = ++s_state.receiptId;
    }

    function cancelRebalanceTask() internal {
        if (s_task.rebalanceTaskId != 0) {
            automate.cancelTask(s_task.rebalanceTaskId);
            s_task.rebalanceTaskId = 0;
        }
    }

    function createSettleTask(uint256 receiptId) internal {
        if (s_task.settleTasks[receiptId] == 0) {
            s_task.settleTasks[receiptId] = _createTask(
                abi.encodeCall(this.resolveSettle, (receiptId)),
                abi.encodeCall(this.settleTask, (receiptId)),
                s_config.settleCheckingInterval
            );
        }
    }

    function cancelSettleTask(uint256 receiptId) internal {
        if (s_task.settleTasks[receiptId] != 0) {
            automate.cancelTask(s_task.settleTasks[receiptId]);
            delete s_task.settleTasks[receiptId];
        }
    }

    function settleTask(uint256 receiptId) external onlyKeeper {
        if (_settle(receiptId)) {
            _payKeeperFee();
        }
    }

    function _payKeeperFee() internal virtual {
        (uint256 fee, ) = _getFeeDetails();
        IKeeperFeePayer payer = IKeeperFeePayer(s_config.market.factory().keeperFeePayer());
        payer.payKeeperFee(address(s_config.market.settlementToken()), fee, automate.gelato());
    }

    function _settle(uint256 receiptId) internal returns (bool) {
        ChromaticLPReceipt memory receipt = s_state.receipts[receiptId];
        IOracleProvider.OracleVersion memory currentOracle = s_config
            .market
            .oracleProvider()
            .currentVersion();
        // TODO check receipt
        if (receipt.oracleVersion < currentOracle.version) {
            if (receipt.action == ChromaticLPAction.ADD_LIQUIDITY) {
                _settleAddLiquidity(receipt);
            } else if (receipt.action == ChromaticLPAction.REMOVE_LIQUIDITY) {
                _settleRemoveLiquidity(receipt);
            } else {
                revert UnknownLPAction();
            }
            // finally remove settle task
            cancelSettleTask(receiptId);
            return true;
        }
        return false;
    }

    function _settleAddLiquidity(ChromaticLPReceipt memory receipt) internal {
        // pass ChromaticLPReceipt as calldata
        // mint and transfer lp pool token to provider in callback
        s_config.market.claimLiquidityBatch(
            s_state.lpReceiptMap[receipt.id].values(),
            abi.encode(receipt)
        );

        _removeReceipt(receipt.id);
    }

    function _settleRemoveLiquidity(ChromaticLPReceipt memory receipt) internal {
        // do claim
        // pass ChromaticLPReceipt as calldata
        s_config.market.withdrawLiquidityBatch(
            s_state.lpReceiptMap[receipt.id].values(),
            abi.encode(receipt)
        );

        _removeReceipt(receipt.id);
    }

    function _distributeAmount(
        uint256 amount
    ) internal view returns (uint256[] memory amounts, uint256 totalAmount) {
        amounts = new uint256[](s_state.feeRates.length);
        for (uint256 i = 0; i < s_state.feeRates.length; ) {
            uint256 _amount = amount.mulDiv(s_state.distributionRates[s_state.feeRates[i]], BPS);

            amounts[i] = _amount;
            totalAmount += _amount;

            unchecked {
                i++;
            }
        }
    }

    function _addReceipt(
        ChromaticLPReceipt memory receipt,
        LpReceipt[] memory lpReceipts
    ) internal {
        s_state.receipts[receipt.id] = receipt;
        EnumerableSet.UintSet storage lpReceiptIdSet = s_state.lpReceiptMap[receipt.id];
        for (uint256 i; i < lpReceipts.length; ) {
            lpReceiptIdSet.add(lpReceipts[i].id);

            unchecked {
                i++;
            }
        }

        s_state.providerMap[receipt.id] = msg.sender;
        EnumerableSet.UintSet storage receiptIdSet = s_state.providerReceiptIds[msg.sender];
        receiptIdSet.add(receipt.id);
    }

    function _removeReceipt(uint256 receiptId) internal {
        delete s_state.receipts[receiptId];
        delete s_state.lpReceiptMap[receiptId];

        address provider = s_state.providerMap[receiptId];
        EnumerableSet.UintSet storage receiptIdSet = s_state.providerReceiptIds[provider];
        receiptIdSet.remove(receiptId);
        delete s_state.providerMap[receiptId];
    }

    function _calcRemoveClbAmounts(
        uint256 lpTokenAmount
    ) internal view returns (uint256[] memory clbTokenAmounts) {
        address[] memory _owners = new address[](s_state.feeRates.length);
        for (uint256 i; i < s_state.feeRates.length; ) {
            _owners[i] = address(this);
            unchecked {
                i++;
            }
        }
        uint256[] memory _clbTokenBalances = IERC1155(s_config.market.clbToken()).balanceOfBatch(
            _owners,
            s_state.clbTokenIds
        );

        clbTokenAmounts = new uint256[](_clbTokenBalances.length);
        for (uint256 i; i < _clbTokenBalances.length; ) {
            clbTokenAmounts[i] = _clbTokenBalances[i].mulDiv(
                lpTokenAmount,
                totalSupply(),
                Math.Rounding.Up
            );

            unchecked {
                i++;
            }
        }
    }

    function _increasePendingClb(LpReceipt[] memory lpReceipts) internal {
        for (uint256 i; i < lpReceipts.length; ) {
            s_state.pendingRemoveClbAmounts[lpReceipts[i].tradingFeeRate] += lpReceipts[i].amount;
            unchecked {
                i++;
            }
        }
    }

    function _decreasePendingClb(
        int16[] calldata feeRates,
        uint256[] calldata burnedCLBTokenAmounts
    ) internal {
        for (uint256 i; i < feeRates.length; ) {
            s_state.pendingRemoveClbAmounts[feeRates[i]] -= burnedCLBTokenAmounts[i];
            unchecked {
                i++;
            }
        }
    }

    function resolveRebalance() external view virtual returns (bool, bytes memory) {}

    function resolveSettle(uint256 receiptId) external view virtual returns (bool, bytes memory) {}

    function rebalance() external virtual {}

    function _addLiquidity(
        uint256 amount,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        (uint256[] memory amounts, uint256 liquidityAmount) = _distributeAmount(
            amount.mulDiv(s_config.utilizationTargetBPS, BPS)
        );

        LpReceipt[] memory lpReceipts = s_config.market.addLiquidityBatch(
            address(this),
            s_state.feeRates,
            amounts,
            abi.encode(
                AddLiquidityBatchCallbackData({
                    provider: msg.sender,
                    liquidityAmount: liquidityAmount,
                    holdingAmount: amount - liquidityAmount
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: nextReceiptId(),
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: amount,
            pendingLiquidity: liquidityAmount,
            recipient: recipient,
            action: ChromaticLPAction.ADD_LIQUIDITY
        });

        _addReceipt(receipt, lpReceipts);
        s_state.pendingAddAmount += liquidityAmount;

        createSettleTask(receipt.id);
    }

    function _removeLiquidity(
        uint256[] memory clbTokenAmounts,
        uint256 lpTokenAmount,
        address recipient
    ) internal returns (ChromaticLPReceipt memory receipt) {
        LpReceipt[] memory lpReceipts = s_config.market.removeLiquidityBatch(
            address(this),
            s_state.feeRates,
            clbTokenAmounts,
            abi.encode(
                RemoveLiquidityBatchCallbackData({
                    provider: msg.sender,
                    lpTokenAmount: lpTokenAmount,
                    clbTokenAmounts: clbTokenAmounts
                })
            )
        );

        receipt = ChromaticLPReceipt({
            id: nextReceiptId(),
            oracleVersion: lpReceipts[0].oracleVersion,
            amount: lpTokenAmount,
            pendingLiquidity: 0,
            recipient: recipient,
            action: ChromaticLPAction.REMOVE_LIQUIDITY
        });

        _addReceipt(receipt, lpReceipts);
        _increasePendingClb(lpReceipts);
        createSettleTask(receipt.id);
    }

    /**
     * @dev implementation of IChromaticLiquidityCallback
     */
    function addLiquidityBatchCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external verifyCallback {
        AddLiquidityBatchCallbackData memory callbackData = abi.decode(
            data,
            (AddLiquidityBatchCallbackData)
        );
        //slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(
            IERC20(settlementToken),
            callbackData.provider,
            vault,
            callbackData.liquidityAmount
        );

        if (callbackData.provider != address(this)) {
            SafeERC20.safeTransferFrom(
                IERC20(settlementToken),
                callbackData.provider,
                address(this),
                callbackData.holdingAmount
            );
        }
    }

    /**
     * @dev implementation of IChromaticLiquidityCallback
     */
    function claimLiquidityBatchCallback(
        uint256[] calldata /* receiptIds */,
        int16[] calldata /* feeRates */,
        uint256[] calldata /* depositedAmounts */,
        uint256[] calldata /* mintedCLBTokenAmounts */,
        bytes calldata data
    ) external verifyCallback {
        ChromaticLPReceipt memory receipt = abi.decode(data, (ChromaticLPReceipt));
        s_state.pendingAddAmount -= receipt.pendingLiquidity;

        if (receipt.recipient != address(this)) {
            uint256 total = totalValue();

            uint256 lpTokenMint = total == receipt.amount
                ? receipt.amount
                : receipt.amount.mulDiv(totalSupply(), total - receipt.amount);
            _mint(receipt.recipient, lpTokenMint);
            emit AddLiquiditySettled({receiptId: receipt.id, lpTokenAmount: lpTokenMint});
        } else {
            emit RebalanceSettled({receiptId: receipt.id});
        }
    }

    /**
     * @dev implementation of IChromaticLiquidityCallback
     */
    function removeLiquidityBatchCallback(
        address clbToken,
        uint256[] calldata clbTokenIds,
        bytes calldata data
    ) external {
        RemoveLiquidityBatchCallbackData memory callbackData = abi.decode(
            data,
            (RemoveLiquidityBatchCallbackData)
        );
        IERC1155(clbToken).safeBatchTransferFrom(
            address(this),
            msg.sender, // market
            clbTokenIds,
            callbackData.clbTokenAmounts,
            bytes("")
        );

        if (callbackData.provider != address(this)) {
            SafeERC20.safeTransferFrom(
                IERC20(this),
                callbackData.provider,
                address(this),
                callbackData.lpTokenAmount
            );
        }
    }

    /**
     * @dev implementation of IChromaticLiquidityCallback
     */
    function withdrawLiquidityBatchCallback(
        uint256[] calldata receiptIds,
        int16[] calldata feeRates,
        uint256[] calldata withdrawnAmounts,
        uint256[] calldata burnedCLBTokenAmounts,
        bytes calldata data
    ) external verifyCallback {
        ChromaticLPReceipt memory receipt = abi.decode(data, (ChromaticLPReceipt));

        _decreasePendingClb(feeRates, burnedCLBTokenAmounts);
        // burn and transfer settlementToken

        if (receipt.recipient != address(this)) {
            uint256 value = totalValue();

            uint256 withdrawnAmount;
            for (uint256 i; i < receiptIds.length; ) {
                withdrawnAmount += withdrawnAmounts[i];
                unchecked {
                    i++;
                }
            }
            // (tokenBalance - withdrawn) * (burningLP /totalSupplyLP) + withdrawn
            uint256 balance = IERC20(s_config.market.settlementToken()).balanceOf(address(this));
            uint256 withdrawAmount = (balance - withdrawnAmount).mulDiv(
                receipt.amount,
                totalSupply()
            ) + withdrawnAmount;

            SafeERC20.safeTransfer(
                s_config.market.settlementToken(),
                receipt.recipient,
                withdrawAmount
            );
            // burningLP: withdrawAmount = totalSupply: totalValue
            // burningLP = withdrawAmount * totalSupply / totalValue
            // burn LPToken requested
            uint256 burningAmount = withdrawAmount.mulDiv(totalSupply(), value);
            _burn(address(this), burningAmount);

            // transfer left lpTokens
            uint256 leftLpToken = receipt.amount - burningAmount;
            if (leftLpToken > 0) {
                SafeERC20.safeTransfer(IERC20(this), receipt.recipient, leftLpToken);
            }

            emit RemoveLiquiditySettled({receiptId: receipt.id});
        } else {
            emit RebalanceSettled({receiptId: receipt.id});
        }
    }

    function _rebalance() internal returns (uint256) {
        // (uint256 total, uint256 clbValue, ) = _poolValue();
        ValueInfo memory value = valueInfo();

        if (value.total == 0) return 0;

        uint256 currentUtility = (value.holdingClb + value.pending - value.pendingClb).mulDiv(
            BPS,
            value.total
        );
        if (uint256(s_config.utilizationTargetBPS + s_config.rebalanceBPS) < currentUtility) {
            uint256[] memory _clbTokenBalances = clbTokenBalances();
            uint256[] memory clbTokenAmounts = new uint256[](s_state.feeRates.length);
            for (uint256 i; i < s_state.feeRates.length; i++) {
                clbTokenAmounts[i] = _clbTokenBalances[i].mulDiv(
                    s_config.rebalanceBPS,
                    currentUtility
                );
            }
            ChromaticLPReceipt memory receipt = _removeLiquidity(clbTokenAmounts, 0, address(this));
            return receipt.id;
        } else if (
            uint256(s_config.utilizationTargetBPS - s_config.rebalanceBPS) > currentUtility
        ) {
            ChromaticLPReceipt memory receipt = _addLiquidity(
                (value.total).mulDiv(s_config.rebalanceBPS, BPS),
                address(this)
            );
            return receipt.id;
        }
        return 0;
    }
}
