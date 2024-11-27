// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Foundry
import {Test} from "forge-std/Test.sol";

// Utils
import {TargetFunctions} from "./TargetFunctions.sol";

/// @title FuzzerFoundry contract
/// @notice Foundry interface for the fuzzer.
contract FuzzerFoundry is Test, TargetFunctions {
    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public {
        setup();

        // Foundry doesn't use config files but does
        // the setup programmatically here

        // target the fuzzer on this contract as it will
        // contain the handler functions
        targetContract(address(this));

        // Add selectors
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = this.handler_mint.selector;
        selectors[1] = this.handler_burn.selector;
        selectors[2] = this.handler_changeSupply.selector;
        selectors[3] = this.handler_transfer.selector;
        selectors[4] = this.handler_rebaseOptIn.selector;
        selectors[5] = this.handler_rebaseOptOut.selector;
        selectors[6] = this.handler_delegateYield.selector;
        selectors[7] = this.handler_undelegateYield.selector;

        // Target selectors
        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));

        // Mint some OETH to dead address to avoid empty contract
        vm.prank(address(vault));
        oeth.mint(dead, 0.01 ether);

        // Mint some OETH to rebaseOptOut dead2 address to avoid empty contract
        vm.prank(address(vault));
        oeth.mint(dead2, 0.01 ether);
        vm.prank(dead2);
        oeth.rebaseOptOut();
    }

    //////////////////////////////////////////////////////
    /// --- INVARIANTS
    //////////////////////////////////////////////////////
    function invariant_A() public {
        //assertTrue(property_A());
    }
}
