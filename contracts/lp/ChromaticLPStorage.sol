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

    function _poolValue()
        public
        view
        returns (uint256 totalValue, uint256 clbValue, uint256 holdingValue)
    {
        holdingValue = IERC20(s_config.market.settlementToken()).balanceOf(address(this));
        clbValue = _poolClbValue();
        holdingValue += _pendingValue();
        totalValue = holdingValue + clbValue;
    }

    function _poolClbValue() internal view returns (uint256 value) {
        uint256[] memory clbSupplies = s_config.market.clbToken().totalSupplyBatch(
            s_state.clbTokenIds
        );
        uint256[] memory binValues = s_config.market.getBinValues(s_state.feeRates);
        uint256[] memory clbTokenAmounts = clbTokenBalances();
        for (uint256 i; i < binValues.length; ) {
            uint256 clbAmount = clbTokenAmounts[i] +
                s_state.pendingRemoveClbAmounts[s_state.feeRates[i]];
            // uint256 clbAmount = clbTokenAmounts[i]; // + _pendingRemoveClbAmounts[_feeRates[i]];
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

    function _pendingValue() internal view returns (uint256) {
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
}
