// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IUSUMLiquidityCallback} from "@usum/core/interfaces/callback/IUSUMLiquidityCallback.sol";
import {LpToken} from "@usum/core/base/market/LpToken.sol";
import {MarketValue} from "@usum/core/base/market/MarketValue.sol";
import {SafeERC20} from "@usum/core/libraries/SafeERC20.sol";
import {LpSlotKey} from "@usum/core/libraries/LpSlotKey.sol";

abstract contract Liquidity is LpToken, MarketValue {
    using Math for uint256;

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant MINIMUM_MARKET_VALUATION = 10 ** 3;

    // uint256 internal lpReserveRatio;

    // onlyDao
    function updateReserveRatio(uint256 _lpReserveRatio) external override {
        // lpReserveRatio = _lpReserveRatio;
    }

    function mint(
        address recipient,
        LpSlotKey slotKey,
        bytes calldata data
    ) external override returns (uint256 liquidity) {
        // uint256 estimatedMarketValue = _estimateMarketValue();
        // uint256 balanceBefore = _balance();
        // IZSUMLiquidityCallback(msg.sender).mintCallback(
        //     address(settlementToken),
        //     data
        // );
        // uint256 amount = _balance() - balanceBefore;
        // if (amount == 0) return 0;
        // // mint lp token
        // uint256 _totalSupply = totalSupply();
        // if (_totalSupply == 0) {
        //     liquidity = amount - MINIMUM_LIQUIDITY;
        //     _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        // } else {
        //     liquidity = _totalSupply.mulDiv(
        //         amount,
        //         estimatedMarketValue > MINIMUM_MARKET_VALUATION
        //             ? estimatedMarketValue
        //             : MINIMUM_MARKET_VALUATION
        //     );
        // }
        // require(liquidity > 0, "Liquidity: insufficient liquidity");
        // _mint(recipient, liquidity);
    }

    function burn(
        address recipient,
        LpSlotKey slotKey,
        bytes calldata data
    ) external override returns (uint256 amount) {
        // uint256 estimatedMarketValue = _estimateMarketValue();
        // uint256 balanceBefore = balanceOf(address(this));
        // IZSUMLiquidityCallback(msg.sender).burnCallback(address(this), data);
        // uint256 liquidity = balanceOf(address(this)) - balanceBefore;
        // if (liquidity == 0) return 0;
        // uint256 _totalSupply = totalSupply();
        // // transfer settlement token
        // amount = estimatedMarketValue.mulDiv(liquidity, _totalSupply);
        // require(
        //     amount <= _unusedMargin(),
        //     "Liquidity: insufficient unused margin"
        // );
        // SafeERC20.safeTransfer(address(settlementToken), recipient, amount);
        // // burn lp token
        // _burn(recipient, liquidity);
    }
}
