// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {LpSlotKey} from "@usum/core/libraries/LpSlotKey.sol";

interface IUSUMLiquidity {
    function mint(
        address recipient,
        LpSlotKey slotKey,
        bytes calldata data
    ) external returns (uint256 liquidity);

    function burn(
        address recipient,
        LpSlotKey slotKey,
        bytes calldata data
    ) external returns (uint256 amount);
}
