// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";
import {IUSUMTradeCallback} from "@usum/core/interfaces/callback/IUSUMTradeCallback.sol";
import {IUSUMLiquidityCallback} from "@usum/core/interfaces/callback/IUSUMLiquidityCallback.sol";
import {Position} from "@usum/core/libraries/Position.sol";
import {IAccount} from "@usum/periphery/interfaces/IAccount.sol";
import {VerifyCallback} from "@usum/periphery/base/VerifyCallback.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract Account is IAccount, VerifyCallback, IERC1155Receiver {
    using EnumerableSet for EnumerableSet.UintSet;

    struct OpenPositionCallbackData {
        address trader;
    }

    address owner;
    address private router;
    bool isInitialized;
    EnumerableSet.UintSet private positionIds;

    error NotRouter();
    error NotOwner();
    error AlreadyInitialized();
    error NotEnoughBalance();
    error NotExistPosition();

    modifier onlyRouter() {
        if (msg.sender != router) revert NotRouter();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function initialize(address _owner, address _router) external {
        if (isInitialized) revert AlreadyInitialized();
        owner = _owner;
        router = _router;
        isInitialized = true;
    }

    function balance(address quote) public view returns (uint256) {
        return IERC20(quote).balanceOf(address(this));
    }

    function withdraw(address quote, uint256 amount) external onlyOwner {
        if (balance(quote) < amount) revert NotEnoughBalance();
        SafeERC20.safeTransfer(quote, owner, amount);
    }

    function transferMargin(
        uint256 marginRequired,
        address marketAddress,
        address settlementToken
    ) external onlyRouter {
        if (balance(settlementToken) < marginRequired)
            revert NotEnoughBalance();

        SafeERC20.safeTransfer(settlementToken, marketAddress, marginRequired);
    }

    function addPositionId(uint256 id) internal {
        positionIds.add(id);
    }

    function removePositionId(uint256 id) internal {
        positionIds.remove(id);
    }

    function hasPositionId(uint256 id) public view returns (bool) {
        return positionIds.contains(id);
    }

    function getPositionIds() external view returns (uint256[] memory) {
        return positionIds.values();
    }

    function openPosition(
        address marketAddress,
        int256 quantity,
        uint32 leverage,
        uint256 takerMargin,
        uint256 makerMargin
    ) external onlyRouter {
        _prepareMarket(marketAddress);

        Position memory position = IUSUMMarket(marketAddress).openPosition(
            quantity,
            leverage,
            takerMargin,
            makerMargin,
            abi.encode(OpenPositionCallbackData({trader: address(this)}))
        );
        addPositionId(position.id);
    }

    function closePosition(
        address marketAddress,
        uint256 positionId
    ) external override onlyRouter {
        if (!hasPositionId(positionId)) revert NotExistPosition();
        _prepareMarket(marketAddress);
        IUSUMMarket(marketAddress).closePosition(
            positionId,
            address(this),
            new bytes(0)
        );
        removePositionId(positionId);
    }

    function openPositionCallback(
        address settlementToken,
        uint256 marginRequired,
        bytes calldata data
    ) external override verifyCallback {
        OpenPositionCallbackData memory callbackData = abi.decode(
            data,
            (OpenPositionCallbackData)
        );
        IAccount traderAccount = IAccount(callbackData.trader);
        traderAccount.transferMargin(
            marginRequired,
            msg.sender,
            settlementToken
        );
    }

    function closePositionCallback(
        address settlementToken,
        uint256 marginTransfered,
        bytes calldata data
    ) external override verifyCallback {}

    function supportsInterface(
        bytes4 interfaceId
    ) external view override returns (bool) {}

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
