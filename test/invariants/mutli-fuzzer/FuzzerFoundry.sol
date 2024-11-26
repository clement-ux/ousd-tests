// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {TargetFunctions} from "./TargetFunctions.sol";

contract FuzzerFoundry is Test, TargetFunctions {
    function setUp() public {
        setup();

        // Foundry doesn't use config files but does
        // the setup programmatically here

        // target the fuzzer on this contract as it will
        // contain the handler functions
        targetContract(address(this));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = this.handler_A.selector;

        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));
    }

    function invariant_A() public {
        assertTrue(property_A());
    }
}
