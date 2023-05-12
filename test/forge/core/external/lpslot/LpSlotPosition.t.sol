// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {LpContext} from "@usum/core/libraries/LpContext.sol";
import {LpSlotPosition, LpSlotPositionLib} from "@usum/core/external/lpslot/LpSlotPosition.sol";
import {PositionParam} from "@usum/core/external/lpslot/PositionParam.sol";
import {IOracleProvider, OracleVersion} from "@usum/core/interfaces/IOracleProvider.sol";
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
        ctx._currentVersionCache = OracleVersion({
            version: 3,
            timestamp: 3,
            price: 2100
        });

        PositionParam memory param = _newPositionParam();
        param._settleVersionCache = OracleVersion({
            version: 2,
            timestamp: 2,
            price: 2000
        });

        position.closePosition(ctx, param);

        assertEq(position.totalLeveragedQty, 50);
        assertEq(position.totalEntryAmount, 100000);
        assertEq(position._totalMakerMargin, 50);
        assertEq(position._totalTakerMargin, 90);
    }

    function _newLpContext() private view returns (LpContext memory) {
        return
            LpContext({
                market: market,
                tokenPrecision: 10 ** 6,
                _pricePrecision: 1,
                _currentVersionCache: OracleVersion(0, 0, 0)
            });
    }

    function _newPositionParam() private pure returns (PositionParam memory) {
        return
            PositionParam({
                oracleVersion: 1,
                leveragedQty: 50,
                takerMargin: 10,
                makerMargin: 50,
                timestamp: 1,
                _settleVersionCache: OracleVersion(0, 0, 0)
            });
    }
}
