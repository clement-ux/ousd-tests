// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Foundry
import {FuzzerFoundry, Test} from "../FuzzerFoundry.sol";

contract Unit is Test {
    FuzzerFoundry f;

    constructor() {
        f = new FuzzerFoundry();
        f.setUp();
    }

    modifier _assert_properties_() {
        _;
        _assert_properties();
    }

    function test_reproduce() public _assert_properties_ {
        // Function used to reproduce failing sequence from Medusa and Echidna
        // As debugging with Foundry is easier.
        // To generate a failing sequence, run the following command:
        // `python test/invariants/multi-fuzzer/debug/convertor.py`
        // Copy and paste the output here. 
    }

    function _assert_properties() internal view {
        assertTrue(f.property_account_A());
        assertTrue(f.property_account_B());
        assertTrue(f.property_account_C());
        assertTrue(f.property_account_D());
        assertTrue(f.property_account_E());
        assertTrue(f.property_balance_A());
        assertTrue(f.property_balance_B());
        assertTrue(f.property_balance_C());
        assertTrue(f.property_balance_D());
        assertTrue(f.property_balance_E());
        assertTrue(f.property_balance_F());
        assertTrue(f.property_balance_G());
        assertTrue(f.property_rebasing_A());
        assertTrue(f.property_rebasing_B());
        assertTrue(f.property_rebasing_D());
        assertTrue(f.property_miscallaneous_A());
        assertTrue(f.property_miscallaneous_B());
        assertTrue(f.property_miscallaneous_C());
        assertTrue(f.property_miscallaneous_D());
        assertTrue(f.property_miscallaneous_E());
        assertTrue(f.property_miscallaneous_F());
    }
}
