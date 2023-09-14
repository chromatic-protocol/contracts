// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {Position} from "@chromatic-protocol/contracts/core/libraries/Position.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {BinMargin} from "@chromatic-protocol/contracts/core/libraries/BinMargin.sol";
import {LiquidityBin, LiquidityBinLib} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityBin.sol";
import {LiquidityPool} from "@chromatic-protocol/contracts/core/libraries/liquidity/LiquidityPool.sol";
import {IInterestCalculator} from "@chromatic-protocol/contracts/core/interfaces/IInterestCalculator.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";
import {CLBToken} from "@chromatic-protocol/contracts/core/CLBToken.sol";

contract LiquidityPoolTest is Test {
    using SafeCast for uint256;
    using LiquidityBinLib for LiquidityBin;

    IOracleProvider provider;
    IInterestCalculator interestCalculator;
    IChromaticVault vault;
    IChromaticMarket market;
    ICLBToken clbToken;
    LiquidityPool liquidityPool;

    function setUp() public {
        provider = IOracleProvider(address(1));
        interestCalculator = IInterestCalculator(address(2));
        vault = IChromaticVault(address(3));
        market = IChromaticMarket(address(4));
        clbToken = new CLBToken();

        vm.mockCall(
            address(interestCalculator),
            abi.encodeWithSelector(interestCalculator.calculateInterest.selector),
            abi.encode(0)
        );

        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.getPendingBinShare.selector),
            abi.encode(0)
        );

        vm.mockCall(
            address(market),
            abi.encodeWithSelector(IERC1155Receiver(address(market)).onERC1155Received.selector),
            abi.encode(IERC1155Receiver(address(market)).onERC1155Received.selector)
        );
        vm.mockCall(
            address(market),
            abi.encodeWithSelector(
                IERC1155Receiver(address(market)).onERC1155BatchReceived.selector
            ),
            abi.encode(IERC1155Receiver(address(market)).onERC1155BatchReceived.selector)
        );

        liquidityPool.initialize();
        liquidityPool._longBins[1]._liquidity.total = 1000 ether;
        liquidityPool._longBins[2]._liquidity.total = 1000 ether;

        clbToken.mint(address(market), 1, 1000 ether, bytes(""));
        clbToken.mint(address(market), 2, 1000 ether, bytes(""));
    }

    function testPrepareBinMargins() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();

        position.setBinMargins(liquidityPool.prepareBinMargins(ctx, position.qty, 1500 ether, 0));

        assertEq(position.qty, 1500 ether);
        assertEq(position._binMargins[0].tradingFeeRate, 1);
        assertEq(position._binMargins[0].amount, 1000 ether);
        assertEq(position._binMargins[0].tradingFee(0), 0.1 ether);
        assertEq(position._binMargins[1].tradingFeeRate, 2);
        assertEq(position._binMargins[1].amount, 500 ether);
        assertEq(position._binMargins[1].tradingFee(0), 0.1 ether);
    }

    function testAcceptOpenPosition() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        position.setBinMargins(liquidityPool.prepareBinMargins(ctx, position.qty, 1500 ether, 0));

        liquidityPool.acceptOpenPosition(ctx, position);

        assertEq(liquidityPool._longBins[1].liquidity(), 1000.1 ether);
        assertEq(liquidityPool._longBins[1].freeLiquidity(), 0.1 ether);
        assertEq(liquidityPool._longBins[2].liquidity(), 1000.1 ether);
        assertEq(liquidityPool._longBins[2].freeLiquidity(), 500.1 ether);
    }

    function testCloseOpenPosition_whenSameRound() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        position.setBinMargins(liquidityPool.prepareBinMargins(ctx, position.qty, 1500 ether, 0));
        liquidityPool.acceptOpenPosition(ctx, position);

        ctx._currentVersionCache.version = 1;
        ctx._currentVersionCache.timestamp = 1;
        position.closeVersion = ctx._currentVersionCache.version;
        position.closeTimestamp = ctx._currentVersionCache.timestamp;

        liquidityPool.acceptClosePosition(ctx, position);
        liquidityPool.acceptClaimPosition(ctx, position, 0);

        assertEq(liquidityPool._longBins[1].liquidity(), 1000.1 ether);
        assertEq(liquidityPool._longBins[1].freeLiquidity(), 1000.1 ether);
        assertEq(liquidityPool._longBins[2].liquidity(), 1000.1 ether);
        assertEq(liquidityPool._longBins[2].freeLiquidity(), 1000.1 ether);
    }

    function testCloseOpenPosition_whenNextRoundWithTakerProfit() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        position.setBinMargins(liquidityPool.prepareBinMargins(ctx, position.qty, 1500 ether, 0));
        liquidityPool.acceptOpenPosition(ctx, position);

        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = 110 ether;
        position.closeVersion = ctx._currentVersionCache.version;
        position.closeTimestamp = ctx._currentVersionCache.timestamp;

        liquidityPool.acceptClosePosition(ctx, position);
        liquidityPool.acceptClaimPosition(ctx, position, 150 ether);

        assertEq(liquidityPool._longBins[1].liquidity(), 900.1 ether);
        assertEq(liquidityPool._longBins[1].freeLiquidity(), 900.1 ether);
        assertEq(liquidityPool._longBins[2].liquidity(), 950.1 ether);
        assertEq(liquidityPool._longBins[2].freeLiquidity(), 950.1 ether);
    }

    function testCloseOpenPosition_whenNextRoundWithTakerLoss() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        position.setBinMargins(liquidityPool.prepareBinMargins(ctx, position.qty, 1500 ether, 0));
        liquidityPool.acceptOpenPosition(ctx, position);

        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = 90 ether;
        position.closeVersion = ctx._currentVersionCache.version;
        position.closeTimestamp = ctx._currentVersionCache.timestamp;

        liquidityPool.acceptClosePosition(ctx, position);
        liquidityPool.acceptClaimPosition(ctx, position, -150 ether);

        assertEq(liquidityPool._longBins[1].liquidity(), 1100.1 ether);
        assertEq(liquidityPool._longBins[1].freeLiquidity(), 1100.1 ether);
        assertEq(liquidityPool._longBins[2].liquidity(), 1050.1 ether);
        assertEq(liquidityPool._longBins[2].freeLiquidity(), 1050.1 ether);
    }

    function testAcceptAddLiquidity() public {
        LpContext memory ctx = _newLpContext();

        liquidityPool.acceptAddLiquidity(ctx, 1, 100 ether);
        assertEq(liquidityPool._longBins[1].liquidity(), 1000 ether);

        // set oracle version to 2
        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = 90 ether;

        liquidityPool.settleAll(ctx);
        assertEq(liquidityPool._longBins[1].liquidity(), 1100 ether);
    }

    function testRemoveLiquidity() public {
        LpContext memory ctx = _newLpContext();

        liquidityPool.acceptRemoveLiquidity(ctx, 1, 100 ether);
        assertEq(liquidityPool._longBins[1].liquidity(), 1000 ether);

        // set oracle version to 2
        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = 90 ether;

        liquidityPool.settleAll(ctx);
        assertEq(liquidityPool._longBins[1].liquidity(), 900 ether);
    }

    function _newLpContext() private view returns (LpContext memory) {
        IOracleProvider.OracleVersion memory _currentVersionCache;
        _currentVersionCache.version = 1;
        _currentVersionCache.timestamp = 1;
        _currentVersionCache.price = 90 ether;
        return
            LpContext({
                oracleProvider: provider,
                interestCalculator: interestCalculator,
                vault: vault,
                clbToken: clbToken,
                market: address(market),
                settlementToken: address(0),
                tokenPrecision: 1e18,
                _currentVersionCache: _currentVersionCache
            });
    }

    function _newPosition() private pure returns (Position memory) {
        return
            Position({
                id: 1,
                openVersion: 1,
                closeVersion: 0,
                qty: 1500 ether,
                takerMargin: 150 ether,
                openTimestamp: 1,
                closeTimestamp: 0,
                owner: address(0),
                _binMargins: new BinMargin[](0),
                _feeProtocol: 0
            });
    }
}
