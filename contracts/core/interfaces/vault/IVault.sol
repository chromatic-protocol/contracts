// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IVault {
    event OnOpenPosition(
        address indexed market,
        uint256 positionId,
        uint256 takerMargin,
        uint256 tradingFee,
        uint256 protocolFee
    );

    event OnClaimPosition(
        address indexed market,
        uint256 positionId,
        address recipient,
        uint256 takerMargin,
        uint256 settlementAmount
    );

    event OnAddLiquidity(address indexed market, uint256 amount);

    event OnSettlePendingLiquidity(address indexed market, uint256 pendingDeposit, uint256 pendingWithdrawal);

    event OnRemoveLiquidity(address indexed market, uint256 amount, address recipient);

    event TransferKeeperFee(uint256 fee, uint256 amount);

    event TransferKeeperFee(address indexed market, uint256 fee, uint256 amount);

    event TransferProtocolFee(address indexed market, uint256 positionId, uint256 amount);

    function onOpenPosition(uint256 positionId, uint256 takerMargin, uint256 tradingFee, uint256 protocolFee) external;

    function onClaimPosition(
        uint256 positionId,
        address recipient,
        uint256 takerMargin,
        uint256 settlementAmount
    ) external;

    function onAddLiquidity(uint256 amount) external;

    function onSettlePendingLiquidity(uint256 pendingDeposit, uint256 pendingWithdrawal) external;

    function onRemoveLiquidity(address recipient, uint256 amount) external;

    function transferKeeperFee(address keeper, uint256 fee, uint256 margin) external returns (uint256 usedFee);
}
