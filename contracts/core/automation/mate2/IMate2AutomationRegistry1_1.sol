// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {ExtraModule} from "./IMate2Automation1_1.sol";

struct ExtraData {
    ExtraModule extraModule;
    bytes extraParam;
}

interface IMate2AutomationRegistry1_1 {
    // function getUpkeepAdmin(address target) external returns (address admin);
    function registerUpkeep(
        address target,
        uint32 gasLimit,
        address admin,
        bool useTreasury,
        bool singleExec,
        bytes calldata checkData,
        ExtraModule extraModule,
        bytes calldata extraParam
    ) external returns (uint256 id);

    function cancelUpkeep(uint256 id) external;

    function pauseUpkeep(uint256 id) external;

    function unpauseUpkeep(uint256 id) external;

    function transferUpkeepAdmin(uint256 id, address proposed) external;

    function updateCheckData(uint256 id, bytes calldata newCheckData) external;

    function getUpkeep(
        uint256 id
    )
        external
        view
        returns (
            address target,
            uint32 executeGas,
            bytes memory checkData,
            ExtraData memory extraData, // to avoid stack too deep
            address lastKeeper,
            address admin,
            uint64 maxValidBlocknumber,
            uint256 amountSpent,
            bool[3] memory flags // [bool useTreasury, bool singleExec, bool paused]
        );

    function getUpkeepTreasury() external view returns (address);

    function checkUpkeep(
        uint256 upkeepId,
        address from,
        bytes calldata extraData
    ) external view returns (bytes memory performData, uint256 maxPayment, uint256 gasLimit);

    function getPerformUpkeepFee() external view returns (uint256 fee);
}
