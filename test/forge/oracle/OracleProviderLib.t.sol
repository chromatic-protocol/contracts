// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {BaseSetup} from "../BaseSetup.sol";
import {IOracleProvider} from "@chromatic-protocol/contracts/oracle/interfaces/IOracleProvider.sol";
import {OracleProviderLegacyMock} from "@chromatic-protocol/contracts/mocks/OracleProviderLegacyMock.sol";
import {OracleProviderPullBasedMock} from "@chromatic-protocol/contracts/mocks/OracleProviderPullBasedMock.sol";
import {OracleProviderLib} from "@chromatic-protocol/contracts/oracle/libraries/OracleProviderLib.sol";

contract OracleProviderLibTest is BaseSetup {
    OracleProviderLegacyMock oracleProviderLegacy;
    OracleProviderPullBasedMock oracleProviderPullBased;

    function setUp() public override {
        super.setUp();
        oracleProviderLegacy = new OracleProviderLegacyMock();
        oracleProviderPullBased = new OracleProviderPullBasedMock();
    }

    function test_isPullBased() public {
        assertEq(OracleProviderLib.isPullBased(IOracleProvider(oracleProvider)), false);
        assertEq(
            OracleProviderLib.isPullBased(IOracleProvider(address(oracleProviderLegacy))),
            false
        );
        assertEq(OracleProviderLib.isPullBased(IOracleProvider(oracleProviderPullBased)), true);
    }
}
