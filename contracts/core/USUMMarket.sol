// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Liquidity} from "@usum/core/base/market/Liquidity.sol";
import { Trade} from "@usum/core/base/market/Trade.sol";
contract USUMMarket is Trade, Liquidity {}
