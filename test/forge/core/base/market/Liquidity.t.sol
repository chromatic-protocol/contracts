// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {BaseSetup} from './BaseSetup.sol';
import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import {IUSUMLiquidityCallback} from '@usum/core/interfaces/callback/IUSUMLiquidityCallback.sol';
import {LpTokenLib} from '@usum/core/libraries/LpTokenLib.sol';

contract LiquidityTest is BaseSetup, IUSUMLiquidityCallback {
    function getKeyList(int16 key) internal pure returns (int16[] memory keys) {
        keys = new int16[](1);
        keys[0] = key;
    }

    function setUp() public override {
        super.setUp();
    }

    function testAddAndRemoveLiquidity() public {
        uint256 addLongAmount = 10 ether;
        uint256 addShortAmount = 20 ether;
        uint256 removeLongAmount = 7 ether;
        uint256 removeShortAmount = 5 ether;

        // add liquidity $10 to 0.01% long slot
        market.addLiquidity(address(this), 1, abi.encode(addLongAmount));
        assertEq(addLongAmount, usdc.balanceOf(address(vault)));
        assertEq(addLongAmount, vault.makerBalances(address(usdc)));
        assertEq(addLongAmount, vault.makerMarketBalances(address(market)));

        assertEq(addLongAmount, market.getSlotLiquidities(getKeyList(1))[0]);

        // add liquidity $20 to 0.1% short slot
        market.addLiquidity(address(this), -10, abi.encode(addShortAmount));
        assertEq(addLongAmount + addShortAmount, usdc.balanceOf(address(vault)));
        assertEq(addLongAmount + addShortAmount, vault.makerBalances(address(usdc)));
        assertEq(addLongAmount + addShortAmount, vault.makerMarketBalances(address(market)));

        assertEq(addShortAmount, market.getSlotLiquidities(getKeyList(-10))[0]);

        // remove liquidity $7 from 0.01% long slot
        market.removeLiquidity(address(this), 1, abi.encode(LpTokenLib.encodeId(1), removeLongAmount));
        assertEq(addLongAmount + addShortAmount - removeLongAmount, usdc.balanceOf(address(vault)));
        assertEq(addLongAmount + addShortAmount - removeLongAmount, vault.makerBalances(address(usdc)));
        assertEq(addLongAmount + addShortAmount - removeLongAmount, vault.makerMarketBalances(address(market)));
        assertEq(addLongAmount - removeLongAmount, market.getSlotLiquidities(getKeyList(1))[0]);

        // remove liquidity $5 from 0.1% short slot
        market.removeLiquidity(address(this), -10, abi.encode(LpTokenLib.encodeId(-10), removeShortAmount));
        assertEq(addLongAmount + addShortAmount - removeLongAmount - removeShortAmount, usdc.balanceOf(address(vault)));
        assertEq(
            addLongAmount + addShortAmount - removeLongAmount - removeShortAmount,
            vault.makerBalances(address(usdc))
        );
        assertEq(
            addLongAmount + addShortAmount - removeLongAmount - removeShortAmount,
            vault.makerMarketBalances(address(market))
        );
        assertEq(addShortAmount - removeShortAmount, market.getSlotLiquidities(getKeyList(-10))[0]);
    }

    function testDistributeMarketEarning() public {
        uint256 addLongAmount = 10 ether;
        uint256 addShortAmount = 20 ether;
        uint256 earning = 10 ether;
        uint256 keeperFee = 1 ether;

        // prepare keeperFeePayer
        address(keeperFeePayer).call{value: keeperFee}('');

        // add liquidity $10 to 0.01% long slot
        market.addLiquidity(address(this), 1, abi.encode(addLongAmount));
        // add liquidity $20 to 0.1% short slot
        market.addLiquidity(address(this), -10, abi.encode(addShortAmount));

        // set markint earning
        usdc.transfer(address(vault), earning);
        vault.setPendingMarketEarnings(address(market), earning);

        // distribute market earning
        vault.distributeMarketEarning(address(market), keeperFee);

        // asserts
        assertEq(addLongAmount + addShortAmount + earning - keeperFee, usdc.balanceOf(address(vault)));
        assertEq(addLongAmount + addShortAmount + earning - keeperFee, vault.makerBalances(address(usdc)));
        assertEq(addLongAmount + addShortAmount + earning - keeperFee, vault.makerMarketBalances(address(market)));
        assertEq(addLongAmount + 3 ether, market.getSlotLiquidities(getKeyList(1))[0]);
        assertEq(addShortAmount + 6 ether, market.getSlotLiquidities(getKeyList(-10))[0]);
    }

    // implement IUSUMLiquidityCallback

    function addLiquidityCallback(address settlementToken, address vault, bytes calldata data) external {
        uint256 amount = abi.decode(data, (uint256));
        usdc.transfer(vault, amount);
    }

    function removeLiquidityCallback(address lpToken, bytes calldata data) external {
        (uint256 id, uint256 amount) = abi.decode(data, (uint256, uint256));
        IERC1155(lpToken).safeTransferFrom(address(this), msg.sender, id, amount, bytes(''));
    }

    // implement IERC1155Receiver

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
