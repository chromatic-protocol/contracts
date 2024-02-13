// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {LpContext} from "@chromatic-protocol/contracts/core/libraries/LpContext.sol";
import {BinPosition, BinPositionLib} from "@chromatic-protocol/contracts/core/libraries/liquidity/BinPosition.sol";
import {PositionParam} from "@chromatic-protocol/contracts/core/libraries/liquidity/PositionParam.sol";
import {IInterestCalculator} from "@chromatic-protocol/contracts/core/interfaces/IInterestCalculator.sol";
import {IChromaticVault} from "@chromatic-protocol/contracts/core/interfaces/IChromaticVault.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";
import {ICLBToken} from "@chromatic-protocol/contracts/core/interfaces/ICLBToken.sol";

contract BinPositionTest is Test {
    using BinPositionLib for BinPosition;

    IOracleProvider provider;
    IInterestCalculator interestCalculator;
    IChromaticVault vault;
    IChromaticMarket market;
    BinPosition position;

    function setUp() public {
        provider = IOracleProvider(address(1));
        interestCalculator = IInterestCalculator(address(2));
        vault = IChromaticVault(address(3));
        market = IChromaticMarket(address(4));

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
    }

    function testOnClosePosition() public {
        position.totalQty = 100;
        position.totalEntryAmount = 200000;
        position._totalMakerMargin = 100;
        position._totalTakerMargin = 100;

        LpContext memory ctx = _newLpContext();
        ctx._currentVersionCache.version = 3;
        ctx._currentVersionCache.timestamp = 3;
        ctx._currentVersionCache.price = 2100 ether;

        PositionParam memory param = _newPositionParam();
        param._entryVersionCache.version = 2;
        param._entryVersionCache.timestamp = 2;
        param._entryVersionCache.price = 2000 ether;

        position.onClosePosition(ctx, param);

        assertEq(position.totalQty, 50);
        assertEq(position.totalEntryAmount, 100000);
        assertEq(position._totalMakerMargin, 50);
        assertEq(position._totalTakerMargin, 90);
    }

    function _newLpContext() private view returns (LpContext memory ctx) {
        IOracleProvider.OracleVersion memory _currentVersionCache;
        _currentVersionCache.version = 1;
        _currentVersionCache.timestamp = 1;
        return
            LpContext({
                oracleProvider: provider,
                interestCalculator: interestCalculator,
                vault: vault,
                clbToken: ICLBToken(address(0)),
                market: address(market),
                settlementToken: address(0),
                tokenPrecision: 1e6,
                _currentVersionCache: _currentVersionCache
            });
    }

    function _newPositionParam() private pure returns (PositionParam memory p) {
        p.openVersion = 1;
        p.qty = 50;
        p.takerMargin = 10;
        p.makerMargin = 50;
        p.openTimestamp = 1;
    }
}
