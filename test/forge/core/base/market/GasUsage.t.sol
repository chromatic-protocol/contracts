// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {BaseSetup} from "./BaseSetup.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {Token} from "@chromatic-protocol/contracts/mocks/Token.sol";
import "forge-std/console.sol";

contract LiquidityTest is BaseSetup {
    _Router router;

    function setUp() public override {
        super.setUp();
        router = new _Router(usdc);
        usdc.approve(address(router), type(uint256).max);
    }

    function test_addLiquidity() public {
        router.addLiquidity_directly(address(market), 1, 10 ether, address(this));
    }

    function test_addLiquidity_by_call() public {
        router.addLiquidity_by_call(address(market), 1, 10 ether, address(this));
    }
}

contract _Router is IChromaticLiquidityCallback {
    using EnumerableSet for EnumerableSet.UintSet;

    struct AddLiquidityCallbackData {
        address provider;
        uint256 amount;
    }

    Token immutable usdc;
    mapping(address => mapping(address => EnumerableSet.UintSet)) private receiptIds; // market => provider => receiptIds

    constructor(Token _usdc) {
        usdc = _usdc;
    }

    function addLiquidity_directly(
        address market,
        int16 feeRate,
        uint256 amount,
        address recipient
    ) public returns (LpReceipt memory receipt) {
        receipt = IChromaticMarket(market).addLiquidity(
            recipient,
            feeRate,
            abi.encode(AddLiquidityCallbackData({provider: msg.sender, amount: amount}))
        );
        receiptIds[market][msg.sender].add(receipt.id);
    }

    function addLiquidity_by_call(
        address market,
        int16 feeRate,
        uint256 amount,
        address recipient
    ) public returns (LpReceipt memory receipt) {
        bytes memory result = _call(
            market,
            abi.encodeWithSelector(
                IChromaticMarket(market).addLiquidity.selector,
                recipient,
                feeRate,
                abi.encode(AddLiquidityCallbackData({provider: msg.sender, amount: amount}))
            )
        );

        receipt = abi.decode(result, (LpReceipt));
        receiptIds[market][msg.sender].add(receipt.id);
    }

    function _call(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory result) = target.call(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        return result;
    }

    // implement IChromaticLiquidityCallback

    function addLiquidityCallback(
        address settlementToken,
        address vault,
        bytes calldata data
    ) external override {
        AddLiquidityCallbackData memory callbackData = abi.decode(data, (AddLiquidityCallbackData));
        SafeERC20.safeTransferFrom(
            IERC20(settlementToken),
            callbackData.provider,
            vault,
            callbackData.amount
        );
    }

    function claimLiquidityCallback(uint256 receiptId, bytes calldata data) external {}

    function removeLiquidityCallback(
        address clbToken,
        uint256 clbTokenId,
        bytes calldata data
    ) external {
        uint256 amount = abi.decode(data, (uint256));
        IERC1155(clbToken).safeTransferFrom(
            address(this),
            msg.sender,
            clbTokenId,
            amount,
            bytes("")
        );
    }

    function withdrawLiquidityCallback(uint256 receiptId, bytes calldata data) external {}
}
