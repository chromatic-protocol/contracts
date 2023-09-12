// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";

import {AutomateReady} from "@chromatic-protocol/contracts/core/base/gelato/AutomateReady.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ChromaticLPReceipt, ChromaticLPAction} from "@chromatic-protocol/contracts/lp/libraries/ChromaticLPReceipt.sol";
import {IAutomate, Module, ModuleData} from "@chromatic-protocol/contracts/core/base/gelato/Types.sol";

import "forge-std/console.sol";

abstract contract ChromaticLPStorage is ERC20, AutomateReady {
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
        uint256 receiptId;
    }

    Config internal s_config;
    Tasks internal s_task;
    State internal s_state;

    event AddLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 amount
    );

    event AddLiquiditySettled(uint256 indexed receiptId, uint256 lpTokenAmount);

    event RemoveLiquidity(
        uint256 indexed receiptId,
        address indexed recipient,
        uint256 oracleVersion,
        uint256 lpTokenAmount
    );

    event RemoveLiquiditySettled(uint256 indexed receiptId);

    event RebalanceLiquidity(uint256 indexed receiptId);
    event RebalanceSettled(uint256 indexed receiptId);

    struct ValueInfo {
        uint256 total;
        uint256 holding;
        uint256 pending;
        uint256 holdingClb;
        uint256 pendingClb;
    }

    constructor(
        AutomateParam memory automateParam
    )
        ERC20("", "")
        AutomateReady(automateParam.automate, address(this), automateParam.opsProxyFactory)
    {}

    function _createTask(
        bytes memory resolver,
        bytes memory execSelector,
        uint256 interval
    ) internal returns (bytes32) {
        ModuleData memory moduleData = ModuleData({modules: new Module[](3), args: new bytes[](3)});
        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.TIME;
        moduleData.modules[2] = Module.PROXY;
        moduleData.args[0] = abi.encode(address(this), resolver); // abi.encodeCall(this.resolveRebalance, ()));
        moduleData.args[1] = abi.encode(uint128(block.timestamp + interval), uint128(interval));
        moduleData.args[2] = bytes("");

        return automate.createTask(address(this), execSelector, moduleData, ETH);
    }

    function utilizationBPS() public view returns (uint16 currentUtility) {
        ValueInfo memory value = valueInfo();
        if (value.total == 0) return 0;
        currentUtility = uint16(
            uint256(value.holdingClb + value.pending - value.pendingClb).mulDiv(BPS, value.total)
        );
    }

    function totalValue() public view returns (uint256 value) {
        value = (holdingValue() + pendingValue() + totalClbValue());
    }

    function valueInfo() public view returns (ValueInfo memory info) {
        info = ValueInfo({
            total: 0,
            holding: holdingValue(),
            pending: pendingValue(),
            holdingClb: holdingClbValue(),
            pendingClb: pendingClbValue()
        });
        info.total = info.holding + info.pending + info.holdingClb + info.pendingClb;
    }

    function holdingValue() public view returns (uint256) {
        return IERC20(s_config.market.settlementToken()).balanceOf(address(this));
    }

    function pendingValue() internal view returns (uint256) {
        return s_state.pendingAddAmount;
        // for (uint256 i; i < _receiptIds.length(); ) {
        //     ChromaticLPReceipt memory receipt = _receipts[_receiptIds.at(i)];
        //     if (receipt.action == ChromaticLPAction.ADD_LIQUIDITY) {
        //         _pendingTotal += receipt.amount;
        //     }
        //     unchecked {
        //         i++;
        //     }
        // }
    }

    function pendingClbValue() public view returns (uint256 value) {
        uint256[] memory clbSupplies = s_config.market.clbToken().totalSupplyBatch(
            s_state.clbTokenIds
        );
        uint256[] memory binValues = s_config.market.getBinValues(s_state.feeRates);
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = s_state.pendingRemoveClbAmounts[s_state.feeRates[i]];
            value += clbAmount == 0 ? 0 : clbAmount.mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                i++;
            }
        }
    }

    function holdingClbValue() public view returns (uint256 value) {
        uint256[] memory clbSupplies = s_config.market.clbToken().totalSupplyBatch(
            s_state.clbTokenIds
        );
        uint256[] memory binValues = s_config.market.getBinValues(s_state.feeRates);
        uint256[] memory clbTokenAmounts = clbTokenBalances();
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = clbTokenAmounts[i];
            value += clbAmount == 0 ? 0 : clbAmount.mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                i++;
            }
        }
    }

    function totalClbValue() public view returns (uint256 value) {
        uint256[] memory clbSupplies = s_config.market.clbToken().totalSupplyBatch(
            s_state.clbTokenIds
        );
        uint256[] memory binValues = s_config.market.getBinValues(s_state.feeRates);
        uint256[] memory clbTokenAmounts = clbTokenBalances();
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = clbTokenAmounts[i] +
                s_state.pendingRemoveClbAmounts[s_state.feeRates[i]];
            value += clbAmount == 0 ? 0 : clbAmount.mulDiv(binValues[i], clbSupplies[i]);
            unchecked {
                i++;
            }
        }
    }

    function clbTokenBalances() public view returns (uint256[] memory _clbTokenBalances) {
        address[] memory _owners = new address[](s_state.feeRates.length);
        for (uint256 i; i < s_state.feeRates.length; ) {
            _owners[i] = address(this);
            unchecked {
                i++;
            }
        }
        _clbTokenBalances = IERC1155(s_config.market.clbToken()).balanceOfBatch(
            _owners,
            s_state.clbTokenIds
        );
    }

    function logLpValue() internal view {
        console.log("{");
        console.log("LP values");
        ChromaticLPStorage.ValueInfo memory value = valueInfo();
        console.log("  total: ", value.total / 10 ** 18);
        console.log("  holding: ", value.holding / 10 ** 18);
        console.log("  pending: ", value.pending / 10 ** 18);
        console.log("  holdingClb: ", value.holdingClb / 10 ** 18);
        console.log("  pendingClb: ", value.pendingClb / 10 ** 18);
        console.log("  utilizationBPS: ", utilizationBPS());
        console.log("}");
    }
}
