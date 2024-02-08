// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ChromaticVault} from "@chromatic-protocol/contracts/core/ChromaticVault.sol";
import {TestSettlementToken} from "@chromatic-protocol/contracts/mocks/TestSettlementToken.sol";
import {ChromaticRouter} from "@chromatic-protocol/contracts/periphery/ChromaticRouter.sol";
import {ChromaticMarket} from "@chromatic-protocol/contracts/core/ChromaticMarket.sol";
import "forge-std/console.sol";

contract MockFlashloanV2 {
    address public owner;
    ChromaticVault public contract_ChromaticVault;
    TestSettlementToken public contract_TestSettlementToken;
    ChromaticRouter public contract_ChromaticRouter;
    ChromaticMarket public contract_ChromaticMarket;

    constructor(address _vault, address _token, address _router, address _market) {
        owner = msg.sender;
        contract_ChromaticVault = ChromaticVault(_vault);
        contract_TestSettlementToken = TestSettlementToken(_token);
        contract_ChromaticRouter = ChromaticRouter(_router);
        contract_ChromaticMarket = ChromaticMarket(payable(_market));

        contract_TestSettlementToken.approve(address(contract_ChromaticRouter), type(uint256).max);
    }

    function flashloan(address token, uint256 amount) public {
        contract_ChromaticVault.flashLoan(token, amount, address(this), abi.encode(amount));
    }

    function flashLoanCallback(uint256 _fee, bytes memory _data) public {
        uint256 amountReceived = abi.decode(_data, (uint256));

        // Send flashloan fee + flashloan
        contract_TestSettlementToken.transfer(
            address(contract_ChromaticVault),
            _fee + amountReceived
        );
    }
}
