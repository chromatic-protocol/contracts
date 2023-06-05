// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Fixed18Lib} from "@equilibria/root/number/types/Fixed18.sol";
import {Position} from "@chromatic/core/libraries/Position.sol";
import {QTY_PRECISION, LEVERAGE_PRECISION} from "@chromatic/core/libraries/PositionUtil.sol";
import {LpContext} from "@chromatic/core/libraries/LpContext.sol";
import {LpSlotMargin} from "@chromatic/core/libraries/LpSlotMargin.sol";
import {LpSlot, LpSlotLib} from "@chromatic/core/external/lpslot/LpSlot.sol";
import {LiquidityPool} from "@chromatic/core/external/lpslot/LiquidityPool.sol";
import {IOracleProvider} from "@chromatic/core/interfaces/IOracleProvider.sol";
import {IInterestCalculator} from "@chromatic/core/interfaces/IInterestCalculator.sol";
import {IChromaticVault} from "@chromatic/core/interfaces/IChromaticVault.sol";
import {IChromaticMarket} from "@chromatic/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic/core/interfaces/ICLBToken.sol";
import {CLBToken} from "@chromatic/core/CLBToken.sol";

contract LiquidityPoolTest is Test {
    using SafeCast for uint256;
    using LpSlotLib for LpSlot;

    IOracleProvider provider;
    IInterestCalculator interestCalculator;
    IChromaticVault vault;
    IChromaticMarket market;
    ICLBToken clbToken;
    LiquidityPool slotSet;

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
            abi.encodeWithSelector(vault.getPendingSlotShare.selector),
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

        slotSet.initialize();
        slotSet._longSlots[1]._liquidity.total = 1000 ether;
        slotSet._longSlots[2]._liquidity.total = 1000 ether;

        clbToken.mint(address(market), 1, 1000 ether, bytes(""));
        clbToken.mint(address(market), 2, 1000 ether, bytes(""));
    }

    function testPrepareSlotMargins() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();

        position.setSlotMargins(slotSet.prepareSlotMargins(position.qty, 1500 ether));

        assertEq(position.leveragedQty(ctx), 1500 ether);
        assertEq(position._slotMargins[0].tradingFeeRate, 1);
        assertEq(position._slotMargins[0].amount, 1000 ether);
        assertEq(position._slotMargins[0].tradingFee(), 0.1 ether);
        assertEq(position._slotMargins[1].tradingFeeRate, 2);
        assertEq(position._slotMargins[1].amount, 500 ether);
        assertEq(position._slotMargins[1].tradingFee(), 0.1 ether);
    }

    function testAcceptOpenPosition() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        position.setSlotMargins(slotSet.prepareSlotMargins(position.qty, 1500 ether));

        slotSet.acceptOpenPosition(ctx, position);

        assertEq(slotSet._longSlots[1].liquidity(), 1000.1 ether);
        assertEq(slotSet._longSlots[1].freeLiquidity(), 0.1 ether);
        assertEq(slotSet._longSlots[2].liquidity(), 1000.1 ether);
        assertEq(slotSet._longSlots[2].freeLiquidity(), 500.1 ether);
    }

    function testCloseOpenPosition_whenSameRound() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        position.setSlotMargins(slotSet.prepareSlotMargins(position.qty, 1500 ether));
        slotSet.acceptOpenPosition(ctx, position);

        ctx._currentVersionCache.version = 1;
        ctx._currentVersionCache.timestamp = 1;
        position.closeVersion = ctx._currentVersionCache.version;
        position.closeTimestamp = ctx._currentVersionCache.timestamp;

        slotSet.acceptClosePosition(ctx, position);
        slotSet.acceptClaimPosition(ctx, position, 0);

        assertEq(slotSet._longSlots[1].liquidity(), 1000.1 ether);
        assertEq(slotSet._longSlots[1].freeLiquidity(), 1000.1 ether);
        assertEq(slotSet._longSlots[2].liquidity(), 1000.1 ether);
        assertEq(slotSet._longSlots[2].freeLiquidity(), 1000.1 ether);
    }

    function testCloseOpenPosition_whenNextRoundWithTakerProfit() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        position.setSlotMargins(slotSet.prepareSlotMargins(position.qty, 1500 ether));
        slotSet.acceptOpenPosition(ctx, position);

        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = Fixed18Lib.from(110);
        position.closeVersion = ctx._currentVersionCache.version;
        position.closeTimestamp = ctx._currentVersionCache.timestamp;

        slotSet.acceptClosePosition(ctx, position);
        slotSet.acceptClaimPosition(ctx, position, 150 ether);

        assertEq(slotSet._longSlots[1].liquidity(), 900.1 ether);
        assertEq(slotSet._longSlots[1].freeLiquidity(), 900.1 ether);
        assertEq(slotSet._longSlots[2].liquidity(), 950.1 ether);
        assertEq(slotSet._longSlots[2].freeLiquidity(), 950.1 ether);
    }

    function testCloseOpenPosition_whenNextRoundWithTakerLoss() public {
        LpContext memory ctx = _newLpContext();
        Position memory position = _newPosition();
        position.setSlotMargins(slotSet.prepareSlotMargins(position.qty, 1500 ether));
        slotSet.acceptOpenPosition(ctx, position);

        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = Fixed18Lib.from(90);
        position.closeVersion = ctx._currentVersionCache.version;
        position.closeTimestamp = ctx._currentVersionCache.timestamp;

        slotSet.acceptClosePosition(ctx, position);
        slotSet.acceptClaimPosition(ctx, position, -150 ether);

        assertEq(slotSet._longSlots[1].liquidity(), 1100.1 ether);
        assertEq(slotSet._longSlots[1].freeLiquidity(), 1100.1 ether);
        assertEq(slotSet._longSlots[2].liquidity(), 1050.1 ether);
        assertEq(slotSet._longSlots[2].freeLiquidity(), 1050.1 ether);
    }

    function testAcceptAddLiquidity() public {
        LpContext memory ctx = _newLpContext();

        slotSet.acceptAddLiquidity(ctx, 1, 100 ether);
        assertEq(slotSet._longSlots[1].liquidity(), 1000 ether);

        // set oracle version to 2
        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = Fixed18Lib.from(90);

        slotSet.settle(ctx);
        assertEq(slotSet._longSlots[1].liquidity(), 1100 ether);
    }

    function testRemoveLiquidity() public {
        LpContext memory ctx = _newLpContext();

        slotSet.acceptRemoveLiquidity(ctx, 1, 100 ether);
        assertEq(slotSet._longSlots[1].liquidity(), 1000 ether);

        // set oracle version to 2
        ctx._currentVersionCache.version = 2;
        ctx._currentVersionCache.timestamp = 2;
        ctx._currentVersionCache.price = Fixed18Lib.from(90);

        slotSet.settle(ctx);
        assertEq(slotSet._longSlots[1].liquidity(), 900 ether);
    }

    function _newLpContext() private view returns (LpContext memory) {
        IOracleProvider.OracleVersion memory _currentVersionCache;
        _currentVersionCache.version = 1;
        _currentVersionCache.timestamp = 1;
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
                qty: int224(150 * QTY_PRECISION.toInt256()),
                leverage: uint32(10 * LEVERAGE_PRECISION),
                takerMargin: 150 ether,
                openTimestamp: 1,
                closeTimestamp: 0,
                owner: address(0),
                _slotMargins: new LpSlotMargin[](0)
            });
    }
}
