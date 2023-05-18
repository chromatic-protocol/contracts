// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Fixed18Lib} from "@equilibria/root/number/types/Fixed18.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotPosition, LpSlotPositionLib} from "@usum/core/external/lpslot/LpSlotPosition.sol";
import {PositionParam} from "@usum/core/external/lpslot/PositionParam.sol";
import {IOracleProvider} from "@usum/core/interfaces/IOracleProvider.sol";
import {IUSUMVault} from "@usum/core/interfaces/IUSUMVault.sol";
import {IUSUMMarket} from "@usum/core/interfaces/IUSUMMarket.sol";

contract LpSlotPositionTest is Test {
    using LpSlotPositionLib for LpSlotPosition;

    IOracleProvider provider;
    IUSUMVault vault;
    IUSUMMarket market;
    LpSlotPosition position;

    function setUp() public {
        provider = IOracleProvider(address(1));
        vault = IUSUMVault(address(2));
        market = IUSUMMarket(address(3));

        vm.mockCall(
            address(vault),
            abi.encodeWithSelector(vault.getPendingSlotShare.selector),
            abi.encode(0)
        );

        vm.mockCall(
            address(market),
            abi.encodeWithSelector(market.oracleProvider.selector),
            abi.encode(provider)
        );
        vm.mockCall(
            address(market),
            abi.encodeWithSelector(market.vault.selector),
            abi.encode(vault)
        );
    }

    function testClosePosition() public {
        position.totalLeveragedQty = 100;
        position.totalEntryAmount = 200000;
        position._totalMakerMargin = 100;
        position._totalTakerMargin = 100;

        LpContext memory ctx = _newLpContext();
        ctx._currentVersionCache.version = 3;
        ctx._currentVersionCache.timestamp = 3;
        ctx._currentVersionCache.price = Fixed18Lib.from(2100);

        PositionParam memory param = _newPositionParam();
        param._settleVersionCache.version = 2;
        param._settleVersionCache.timestamp = 2;
        param._settleVersionCache.price = Fixed18Lib.from(2000);

        position.closePosition(ctx, param);

        assertEq(position.totalLeveragedQty, 50);
        assertEq(position.totalEntryAmount, 100000);
        assertEq(position._totalMakerMargin, 50);
        assertEq(position._totalTakerMargin, 90);
    }

    function _newLpContext() private view returns (LpContext memory ctx) {
        ctx.market = market;
        ctx.tokenPrecision = 10 ** 6;
    }

    function _newPositionParam() private pure returns (PositionParam memory p) {
        p.oracleVersion = 1;
        p.leveragedQty = 50;
        p.takerMargin = 10;
        p.makerMargin = 50;
        p.timestamp = 1;
    }
}
