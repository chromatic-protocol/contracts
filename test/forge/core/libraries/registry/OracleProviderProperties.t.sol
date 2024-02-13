// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {OracleProviderProperties} from "@chromatic-protocol/contracts/core/libraries/registry/OracleProviderProperties.sol";

contract OracleProviderPropertiesTest is Test {
    function testMaxAllowableLeverage() public {
        OracleProviderProperties memory props = OracleProviderProperties(0, 0, 0);
        assertEq(props.maxAllowableLeverage(), 10);

        props.leverageLevel = 1;
        assertEq(props.maxAllowableLeverage(), 20);

        props.leverageLevel = 2;
        assertEq(props.maxAllowableLeverage(), 50);

        props.leverageLevel = 3;
        assertEq(props.maxAllowableLeverage(), 100);

        props.leverageLevel = 4;
        assertEq(props.maxAllowableLeverage(), 0);
    }
}
