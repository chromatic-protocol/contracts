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

abstract contract ChromaticLPBase is AutomateReady {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint16 constant BPS = 10000;

    struct AutomateParam {
        address automate;
        address opsProxyFactory;
    }

    struct Config {
        IChromaticMarket market;
        uint16 utilizationTargetBPS;
        uint16 rebalanceBPS;
        uint256 rebalnceCheckingInterval;
        uint256 settleCheckingInterval;
    }

    struct Tasks {
        bytes32 rebalanceTaskId;
        mapping(uint256 => bytes32) settleTasks;
    }

    struct State {
        int16[] feeRates;
        mapping(int16 => uint16) distributionRates;
        uint256[] clbTokenIds;

        mapping(uint256 => ChromaticLPReceipt) receipts; // receiptId => receipt
        mapping(uint256 => EnumerableSet.UintSet) lpReceiptMap; // receiptId => lpReceiptIds
        mapping(uint256 => address) providerMap; // receiptId => provider
        mapping(address => EnumerableSet.UintSet) providerReceiptIds; // provider => receiptIds
        uint256 pendingAddAmount; // in settlement token
        mapping(int16 => uint256) pendingRemoveClbAmounts; // feeRate => pending remove
    }

    error InvalidUtilizationTarget(uint16 targetBPS);
    error InvalidRebalanceBPS();
    error NotMatchDistributionLength(uint256 feeLength, uint256 distributionLength);
    error InvalidDistributionSum();
    error AlreadyRebalanceTaskExist();

    error NotMarket();
    error OnlyBatchCall();

    error UnknownLPAction();
    error NotOwner();
    error AlreadySwapRouterConfigured();
    error NotKeeperCalled();

    Config internal s_config;
    Tasks internal s_task;
    State internal s_state;

    modifier verifyCallback() virtual {
        if (address(s_config.market) != msg.sender) revert NotMarket();
        _;
    }

    constructor(AutomateParam memory automateParam ) AutomateReady(
        automateParam.automate, 
        address(this), 
        automateParam.opsProxyFactory
        ) {
    }

    // region initialization
    function _initialize(Config memory config, int16[] memory feeRates, uint16[] memory distributionRates) internal {
        _validateConfig(config.utilizationTargetBPS, config.rebalanceBPS, feeRates, distributionRates
        );
        s_config = Config({
            market: config.market,
            utilizationTargetBPS: config.utilizationTargetBPS,
            rebalanceBPS: config.rebalanceBPS,
            rebalnceCheckingInterval: config.rebalnceCheckingInterval,
            settleCheckingInterval: config.settleCheckingInterval
        });
        _setupState(feeRates, distributionRates);
    }

    function _validateConfig(
        uint16 utilizationTargetBPS,
        uint16 rebalanceBPS,
        int16[] memory feeRates,
        uint16[] memory distributionRates
    ) private pure {
        if (utilizationTargetBPS > BPS) revert InvalidUtilizationTarget(utilizationTargetBPS);
        if (feeRates.length != distributionRates.length)
            revert NotMatchDistributionLength(feeRates.length, distributionRates.length);

        if (utilizationTargetBPS <= rebalanceBPS) revert InvalidRebalanceBPS();
    }

    function _setupState(
        int16[] memory feeRates,
        uint16[] memory distributionRates
    ) private {
        uint16 totalRate;
        for (uint256 i; i < distributionRates.length; ) {
            s_state.distributionRates[feeRates[i]] = distributionRates[i];
            totalRate += distributionRates[i];

            unchecked {
                i++;
            }
        }
        if (totalRate != BPS) revert InvalidDistributionSum();
        s_state.feeRates = feeRates;
        
        _setupClbTokenIds(feeRates);
    }

    function _setupClbTokenIds(int16[] memory feeRates) private {
        s_state.clbTokenIds = new uint256[](feeRates.length);
        for (uint256 i; i < feeRates.length; ) {
            s_state.clbTokenIds[i] = CLBTokenLib.encodeId(feeRates[i]);

            unchecked {
                i++;
            }
        }
    }

    // endregion

}
