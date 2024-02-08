// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./FuzzHelper.sol";
import "./FuzzProperties.sol";

/**
Linux (Bash):
To run the fuzzer a single time:
    export FUZZ_ENTROPY=$(echo -n $RANDOM);forge test -vv --match-contract Fuzzer --match-test test_all_properties

Re-run with a specific ENTROPY, in this case 7347:
    export FUZZ_ENTROPY=$(echo -n 18717);forge test -vvvv --match-contract Fuzzer --match-test test_all_properties

To run the fuzzer with 100 runs:
    for i in `seq 1 1000`; do export FUZZ_ENTROPY=$(echo -n $RANDOM);forge test --match-contract Fuzzer --match-test test_all_properties; done
    (To find errors: grep -L "RUN_SUCCESS" test/halborn/fuzzer/logs/*)

Windows (Powershell):
To run the fuzzer a single time:
    $env:FUZZ_ENTROPY = Get-Random;forge test -vvvv --match-contract Fuzzer --match-test test_all_properties

Re-run with a specific ENTROPY, in this case 7347:
    $env:FUZZ_ENTROPY = 7347;forge test -vvvv --match-contract Fuzzer --match-test test_all_properties

To run the fuzzer with 100 runs:
    for ($i=0; $i -lt 100; $i++) { $env:FUZZ_ENTROPY = Get-Random;forge test --match-contract Fuzzer --match-test test_all_properties }
*/

contract Fuzzer is FuzzHelper, FuzzProperties {
    using Strings for *;

    function setUp() public virtual {}

    function test_all_properties() public {
        setUpEnvTests();
        vm.warp(block.timestamp + 1 weeks);
        uint256 selection;
        address _user;
        for (uint256 j; j < STATES; ++j){
            if (enableDebugToFile){
                line = string.concat("NewState(", Strings.toString(j), ")");
                vm.writeLine(path, line);
            }
            for (uint256 i; i < state_makers.length; ++i){
                line = string.concat("    ENTERED MAKER LOOP ", Strings.toString(i));
                vm.writeLine(path, line);
                _user = state_makers[i];
                selection = contract_FuzzRandomizer.getRandomNumberWithEntropy(uint256(uint160(_user))) % 4; 
                line = string.concat("    SELECTION MAKER ", Strings.toString(selection));
                vm.writeLine(path, line);
                _executeMakerAction(_user, selection, j);
            } // end user for loop
            for (uint256 i; i < state_takers.length; ++i){
                line = string.concat("    ENTERED TAKER LOOP ", Strings.toString(i));
                vm.writeLine(path, line);
                _user = state_takers[i];
                selection = contract_FuzzRandomizer.getRandomNumberWithEntropy(uint256(uint160(_user))) % 3; 
                line = string.concat("    SELECTION TAKER ", Strings.toString(selection));
                vm.writeLine(path, line);
                _executeTakerAction(_user, selection, j);
            } // end user for loop
            _checkInvariantsAndProperties();
            _endStateActions();
        } // end STATES for loop
        if (enableDebugToFile){
            line = "RUN_SUCCESS";
            vm.writeLine(path, line);
        }
    }
}