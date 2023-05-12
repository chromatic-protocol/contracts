// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import {ILendingPool} from "@usum/core/interfaces/vault/ILendingPool.sol";
import {IVault} from "@usum/core/interfaces/vault/IVault.sol";

interface IUSUMVault is IVault, ILendingPool {}
