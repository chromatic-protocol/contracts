// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Liquidity} from "@usum/core/base/market/Liquidity.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract USUMMarket is Liquidity {
    constructor() ERC1155("") {}
}
