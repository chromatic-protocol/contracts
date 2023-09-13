// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {IChromaticLP} from "@chromatic-protocol/contracts/lp/interfaces/IChromaticLP.sol";
import {ChromaticLPBase} from "@chromatic-protocol/contracts/lp/ChromaticLPBase.sol";
import {ChromaticLPLogic} from "@chromatic-protocol/contracts/lp/ChromaticLPLogic.sol";
import {ChromaticLPReceipt} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

uint16 constant BPS = 10000;

contract ChromaticLP is ChromaticLPBase, Proxy, IChromaticLP, IChromaticLiquidityCallback {
    // using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    address public immutable CHROMATIC_LP_LOGIC;

    constructor(
        ChromaticLPLogic lpLogic,
        Config memory config,
        int16[] memory feeRates,
        uint16[] memory distributionRates,
        AutomateParam memory automateParam
    ) ChromaticLPBase(automateParam) {
        CHROMATIC_LP_LOGIC = address(lpLogic);

        _initialize(config, feeRates, distributionRates);

        _createRebalanceTask();
    }

    function _createRebalanceTask() internal {
        if (s_task.rebalanceTaskId != 0) revert AlreadyRebalanceTaskExist();
        s_task.rebalanceTaskId = _createTask(
            abi.encodeCall(this.resolveRebalance, ()),
            abi.encodeCall(this.rebalance, ()),
            s_config.rebalnceCheckingInterval
        );
    }

    /**
     * @dev This is the address to which proxy functions are delegated to
     */
    function _implementation() internal view virtual override returns (address) {
        return CHROMATIC_LP_LOGIC;
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function addLiquidity(
        uint256 /* amount */,
        address /* recipient */
    ) external override returns (ChromaticLPReceipt memory /* receipt */) {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function removeLiquidity(
        uint256 /* lpTokenAmount */,
        address /* recipient */
    ) external override returns (ChromaticLPReceipt memory /* receipt */) {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function settle(uint256 /* receiptId */) external override returns (bool) {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function resolveSettle(
        uint256 receiptId
    ) public view override(IChromaticLP) returns (bool, bytes memory) {
        return _resolveSettle(receiptId, this.settleTask);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function resolveRebalance() external view override(IChromaticLP) returns (bool, bytes memory) {
        return _resolveRebalance(this.rebalance);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function market() external view override returns (address) {
        return address(s_config.market);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function settlementToken() external view override returns (address) {
        return address(s_config.market.settlementToken());
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function lpToken() external view override returns (address) {
        return address(this);
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function getReceiptIdsOf(
        address owner
    ) external view override returns (uint256[] memory receiptIds) {
        return s_state.providerReceiptIds[owner].values();
    }

    /**
     * @inheritdoc IChromaticLP
     */
    function getReceipt(
        uint256 receiptId
    ) external view override returns (ChromaticLPReceipt memory) {
        return s_state.receipts[receiptId];
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function addLiquidityCallback(address, address, bytes calldata) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function claimLiquidityCallback(
        uint256 /* receiptId */,
        int16 /* feeRate */,
        uint256 /* depositedAmount */,
        uint256 /* mintedCLBTokenAmount */,
        bytes calldata /* data */
    ) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function removeLiquidityCallback(
        address /* clbToken */,
        uint256 /* clbTokenId */,
        bytes calldata /* data */
    ) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function withdrawLiquidityCallback(
        uint256 /* receiptId */,
        int16 /* feeRate */,
        uint256 /* withdrawnAmount */,
        uint256 /* burnedCLBTokenAmount */,
        bytes calldata /* data */
    ) external pure override {
        revert OnlyBatchCall();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function addLiquidityBatchCallback(
        address /* settlementToken */,
        address /* vault */,
        bytes calldata /* data */
    ) external override {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function claimLiquidityBatchCallback(
        uint256[] calldata /* receiptIds */,
        int16[] calldata /* feeRates */,
        uint256[] calldata /* depositedAmounts */,
        uint256[] calldata /* mintedCLBTokenAmounts */,
        bytes calldata /* data */
    ) external override {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function removeLiquidityBatchCallback(
        address /* clbToken */,
        uint256[] calldata /* clbTokenIds */,
        bytes calldata /* data */
    ) external override {
        _fallback();
    }

    /**
     * @inheritdoc IChromaticLiquidityCallback
     * @dev not implemented
     */
    function withdrawLiquidityBatchCallback(
        uint256[] calldata /* receiptIds */,
        int16[] calldata /* feeRates */,
        uint256[] calldata /* withdrawnAmounts */,
        uint256[] calldata /* burnedCLBTokenAmounts */,
        bytes calldata /* data */
    ) external override {
        _fallback();
    }

    /**
     * @inheritdoc IERC1155Receiver
     */
    function onERC1155Received(
        address /* operator */,
        address /* from */,
        uint256 /* id */,
        uint256 /* value */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @inheritdoc IERC1155Receiver
     */
    function onERC1155BatchReceived(
        address /* operator */,
        address /* from */,
        uint256[] calldata /* ids */,
        uint256[] calldata /* values */,
        bytes calldata /* data */
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return
            interfaceID == this.supportsInterface.selector || // ERC165
            interfaceID == this.onERC1155Received.selector ^ this.onERC1155BatchReceived.selector; // IERC1155Receiver
    }

    /**
     * @dev called by keeper only
     */
    function rebalance() external {
        _fallback();
    }

    /**
     * @dev called by Keeper only
     */
    function settleTask(uint256 /* receiptId */) external {
        _fallback();
    }
}
