// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@chromatic-protocol/contracts/core/automation/gelato/AutomateReady.sol";
import "@chromatic-protocol/contracts/core/automation/gelato/Types.sol";

contract GelatoTest is AutomateReady {
    mapping(uint256 taskIdx => uint256 fund) funds;
    mapping(uint256 taskIdx => address funder) funders;
    mapping(uint256 taskIdx => uint256 blockNumber) blockNumbers;

    uint256 private _taskIdx;

    event TaskCreated(uint256 indexed taskIdx, bytes32 taskId);
    event TaskExecuted(uint256 indexed taskIdx, uint256 fee, bool success);

    constructor(address _automate) AutomateReady(_automate, address(this)) {}

    function createTask() external payable {
        _taskIdx++;

        funds[_taskIdx] = msg.value;
        funders[_taskIdx] = msg.sender;

        ModuleData memory moduleData = ModuleData({modules: new Module[](4), args: new bytes[](4)});

        moduleData.modules[0] = Module.RESOLVER;
        moduleData.modules[1] = Module.PROXY;
        moduleData.modules[2] = Module.SINGLE_EXEC;
        moduleData.modules[3] = Module.TRIGGER;
        moduleData.args[0] = abi.encode(address(this), abi.encodeCall(this.resolve, (_taskIdx)));
        moduleData.args[1] = bytes("");
        moduleData.args[2] = bytes("");
        moduleData.args[3] = abi.encode(TriggerType.BLOCK, bytes(""));

        bytes32 taskId = automate.createTask(
            address(this),
            abi.encode(this.exec.selector),
            moduleData,
            ETH
        );

        emit TaskCreated(_taskIdx, taskId);
    }

    function resolve(
        uint256 taskIdx
    ) external view returns (bool canExec, bytes memory execPayload) {
        canExec = block.timestamp - blockNumbers[taskIdx] > 10;
        execPayload = canExec ? abi.encodeCall(this.exec, (taskIdx)) : bytes("");
    }

    function exec(uint256 taskIdx) external {
        uint256 fund = funds[taskIdx];
        address funder = funders[taskIdx];

        (uint256 fee, ) = _getFeeDetails();
        (bool s, ) = IGelato(automate.gelato()).feeCollector().call{value: fee}("");
        (bool success, ) = funder.call{value: fund - fee}("");

        emit TaskExecuted(taskIdx, fee, success);
    }
}
