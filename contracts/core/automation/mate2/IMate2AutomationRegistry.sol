// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IMate2AutomationRegistry {
    function registerUpkeep(
        address target,
        uint32 gasLimit,
        address admin,
        bool useTreasury,
        bool singleExec,
        bytes calldata checkData
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
            address lastKeeper,
            address admin,
            uint64 maxValidBlocknumber,
            uint256 amountSpent,
            bool useTreasury,
            bool singleExec,
            bool paused
        );

    function getUpkeepTreasury() external view returns (address);

    function checkUpkeep(
        uint256 upkeepId,
        address from
    ) external view returns (bytes memory performData, uint256 maxLinkPayment, uint256 gasLimit);

    function getPerformUpkeepFee() external view returns (uint256 fee);

    function addWhitelistedRegistrar(address registrar) external;

    function removeWhitelistedRegistrar(address registrar) external;
}
