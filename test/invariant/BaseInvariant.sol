// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Test imports
import {Shared_Test_} from "test/Shared.sol";

import {StableMath} from "origin/utils/StableMath.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Handlers
import {OETHHandler} from "./handlers/OETHHandler.sol";

abstract contract Invariant_Base_Test_ is Shared_Test_ {
    using SafeMath for uint256;
    using StableMath for uint256;

    //////////////////////////////////////////////////////
    /// --- STORAGE
    //////////////////////////////////////////////////////
    address[] public holders;

    OETHHandler internal oethHandler;

    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public virtual override {
        super.setUp();
    }

    //////////////////////////////////////////////////////
    /// --- INVARIANTS
    //////////////////////////////////////////////////////

    // --- Total Supply & Balances ---
    // Invariant A: totalSupply <= MAX_SUPPLY
    // Invariant B: totalSupply == ∑user balance, ∀ user
    // Invariant C: totalSupply == _rebasingCredits / _rebasingCreditsPerToken + nonRebasingSupply
    // Invariant D: nonRebasingSupply == ∑user balance, ∀ rebasedOptOut user
    // --- WIP ---
    // Invariant x: _rebasingCredits  == ∑user _creditBalances, ∀ rebasedOptIn  user
    // Invariant x: _rebasingCreditsPerToken <= 1e27
    // Invariant x: ∀ user, balance == sum_of_mint - sum_of_burn - sum_of_send + sum_of_receive
    // Invariant x: ∀ rebasedOptIn  user, nonRebasingCreditsPerToken == 0
    // Invariant x: ∀ rebasedOptOut user, nonRebasingCreditsPerToken == _rebasingCreditsPerToken

    function assert_Invariant_A() public view {
        uint256 totalSupply = oeth.totalSupply();

        assertGe(~uint128(0), totalSupply, "totalSupply > MAX_SUPPLY");
    }

    function assert_Invariant_B(uint256 errorAbs) public view {
        uint256 totalSupply = oeth.totalSupply();

        assertApproxEqAbs(totalSupply, _sumUsersBalance(), errorAbs, "totalSupply == sum user balance, for each user");
    }

    function assert_Invariant_C(uint256 errorAbs) public view {
        uint256 totalSupply = oeth.totalSupply();
        uint256 rebasingCredits = oeth.rebasingCreditsHighres();
        uint256 rebasingCreditsPerToken = oeth.rebasingCreditsPerTokenHighres();
        uint256 nonRebasingSupply = oeth.nonRebasingSupply();

        assertApproxEqAbs(
            totalSupply,
            rebasingCredits.divPrecisely(rebasingCreditsPerToken).add(nonRebasingSupply),
            errorAbs,
            "totalSupply == _rebasingCredits / _rebasingCreditsPerToken + nonRebasingSupply"
        );
    }

    function assert_Invariant_D(uint256 threshhold, uint256 errorAbs) public view {
        uint256 nonRebasingSupply = oeth.nonRebasingSupply();

        if (nonRebasingSupply < threshhold) return;

        assertApproxEqAbs(
            nonRebasingSupply,
            _sumUsersBalanceOut(),
            errorAbs,
            "nonRebasingSupply == sum user balance, for each rebasedOptOut user"
        );
    }

    function _sumUsersBalance() public view returns (uint256 sum) {
        for (uint256 i = 0; i < holders.length; i++) {
            sum += oeth.balanceOf(holders[i]);
        }
        sum += oeth.balanceOf(dead);
    }

    function _sumUsersBalanceOut() public view returns (uint256 sum) {
        for (uint256 i = 0; i < holders.length; i++) {
            if (_isNonRebasingAccount(holders[i])) {
                sum += oeth.balanceOf(holders[i]);
            }
        }
    }

    function _isNonRebasingAccount(address _user) internal view returns (bool) {
        return oeth.nonRebasingCreditsPerToken(_user) > 0;
    }
}
