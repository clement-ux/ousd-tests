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
        vm.prank(dead2);
        oeth.rebaseOptOut();
        vm.prank(address(vault));
        oeth.mint(dead2, 0.01 ether);
    }

    //////////////////////////////////////////////////////
    /// --- ACCOUNT INVARIANTS
    //////////////////////////////////////////////////////
    function invariant_account_A() public view {
        assertTrue(property_account_A());
    }

    function invariant_account_B() public view {
        assertTrue(property_account_B());
    }

    function invariant_account_C() public view {
        assertTrue(property_account_C());
    }

    function invariant_account_D() public view {
        assertTrue(property_account_D());
    }

    function invariant_account_E() public view {
        assertTrue(property_account_E());
    }

    //////////////////////////////////////////////////////
    /// --- BALANCE INVARIANTS
    //////////////////////////////////////////////////////
    function invariant_balance_A() public view {
        // Not implemented yet
    }

    // Failling
    function invariant_balance_B() public view {
        assertTrue(property_balance_B());
    }

    // Failling
    function invariant_balance_C() public view {
        assertTrue(property_balance_C());
    }

    // Failling
    function invariant_balance_D() public view {
        assertTrue(property_balance_D());
        // This invariant is failling because:
        // When changeSupply is called, rebasingCreditsPerToken_ is rounded-down.
        // Then balanceOf is over-estimtaed.
        // How to solve it?
        // rebasingCreditsPerToken_ =
        //     ((rebasingCredits_ * 1e18 + (totalSupply - nonRebasingSupply - 1)) /
        //     (totalSupply - nonRebasingSupply);
    }

    // Failling
    function invariant_balance_E() public view {
        assertTrue(property_balance_E());
    }

    // Failling
    function invariant_balance_F() public view {
        assertTrue(property_balance_F());
    }

    function invariant_balance_G() public view {
        // Not implemented yet
    }

    //////////////////////////////////////////////////////
    /// --- REBASING INVARIANTS
    //////////////////////////////////////////////////////
    function invariant_rebasing_A() public view {
        assertTrue(property_rebasing_A());
        assertTrue(property_rebasing_B());
    }

    //////////////////////////////////////////////////////
    /// --- MISCALLANEOUS INVARIANTS
    //////////////////////////////////////////////////////
    function invariant_miscallaneous_A_B_E_F() public view {
        assertTrue(property_miscallaneous_A());

        assertTrue(property_miscallaneous_B());
        // This invariant is failling because:
        // When rebaseOptIn is called, _balanceToRebasingCredits calculs user credits.
        // But credits are rounded-up, which increase balanceOf when user rebaseOptIn.
        // How to solve it?
        // Round-down credits in _balanceToRebasingCredits, but is it really a problem?

        // This two following invariants are failling because:
        // When mint/burn is called, _balanceToRebasingCredits calculs user credits.
        // But credits are rounded-up, which increase the previous balanceOf too.
        // Then when in the rare situation where `rebasingCreditsPerToken` < 1e18, when calculating `balanceOf`,
        // dividing by rebasingCreditsPerToken will start to bring errors instead of removing it! (because 1e16 < 1e18)
        // In the current implementation, why a totalSupply < 10B ether, min rebasingCreditsPerToken is 1e16.
        // Then the maximum error is 99 wei.
        // How to solve it?
        // Round-down credits in _balanceToRebasingCredits, but maximum error is bellow 100 wei, so is it really a problem?
        assertTrue(property_miscallaneous_E());
        assertTrue(property_miscallaneous_F());
    }

    function invariant_miscallaneous_C_D() public view {
        assertTrue(property_miscallaneous_C());
        assertTrue(property_miscallaneous_D());
    }
}
