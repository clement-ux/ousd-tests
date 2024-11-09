// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Test imports
import {Shared_Test_} from "test/Shared.sol";

// Contract
import {OUSD} from "origin/token/OUSD.sol";

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
    // Invariant E: _rebasingCredits  == ∑user _creditBalances, ∀ rebasedOptIn  user
    // Invariant F: _rebasingCreditsPerToken <= 1e27
    // Invariant G: ∀ rebasedOptIn  user, nonRebasingCreditsPerToken == 0
    // Invariant G: ∀ rebasedOptOut user, nonRebasingCreditsPerToken >= _rebasingCreditsPerToken 
    // Invariant H: ∀ user rebasedOptIn, balanceOf == _creditBalances / _rebasingCreditsPerToken // note: useless like this, need to change
    // Invariant H: ∀ user rebasedOptOut, balanceOf == _creditBalances / nonRebasingCreditsPerToken[_account] // note: useless like this, need to change
    // Invariant I: ∀ user rebasedOptIn, rebaseState == RebaseState.OPT_IN
    // Invariant I: ∀ user rebasedOptOut, rebaseState == RebaseState.OPT_OUT

    function assert_Invariant_A() public view {
        uint256 totalSupply = oeth.totalSupply();

        assertGe(~uint128(0), totalSupply, "totalSupply > MAX_SUPPLY");
    }

    function assert_Invariant_B(uint256 errorRel) public view {
        uint256 totalSupply = oeth.totalSupply();

        assertApproxEqRel(totalSupply, _sumUsersBalance(), errorRel, "totalSupply == sum user balance, for each user");
    }

    function assert_Invariant_C(uint256 errorRel) public view {
        uint256 totalSupply = oeth.totalSupply();
        uint256 rebasingCredits = oeth.rebasingCreditsHighres();
        uint256 rebasingCreditsPerToken = oeth.rebasingCreditsPerTokenHighres();
        uint256 nonRebasingSupply = oeth.nonRebasingSupply();

        assertApproxEqRel(
            totalSupply,
            rebasingCredits.divPrecisely(rebasingCreditsPerToken).add(nonRebasingSupply),
            errorRel,
            "totalSupply == _rebasingCredits / _rebasingCreditsPerToken + nonRebasingSupply"
        );
    }

    function assert_Invariant_D(uint256 threshhold, uint256 errorRel) public view {
        uint256 nonRebasingSupply = oeth.nonRebasingSupply();

        if (nonRebasingSupply < threshhold) return;

        assertApproxEqRel(
            nonRebasingSupply,
            _sumUsersBalanceOut(),
            errorRel,
            "nonRebasingSupply == sum user balance, for each rebasedOptOut user"
        );
    }

    function assert_Invariant_E(uint256 errorRel) public view {
        uint256 rebasingCredits = oeth.rebasingCreditsHighres();

        assertApproxEqRel(
            rebasingCredits,
            _sumCreditBalanceIn(),
            errorRel,
            "rebasingCredits == sum user credit balance, for each rebasedOptIn user"
        );
    }

    function assert_Invariant_F() public view {
        assertGe(1e27, oeth.rebasingCreditsPerTokenHighres(), "rebasingCreditsPerToken <= 1e27");
    }

    function assert_Invariant_G() public view {
        for (uint256 i = 0; i < holders.length; i++) {
            if (!_isNonRebasingAccount(holders[i])) {
                assertEq(
                    0,
                    oeth.nonRebasingCreditsPerToken(holders[i]),
                    "nonRebasingCreditsPerToken == 0, for each rebasedOptIn user"
                );
            } else {
                assertGe(
                    oeth.nonRebasingCreditsPerToken(holders[i]),
                    oeth.rebasingCreditsPerTokenHighres(),
                    "nonRebasingCreditsPerToken >= _rebasingCreditsPerToken, for each rebasedOptOut user"
                );
            }
        }
    }

    function assert_Invariant_H(uint256 errorAbsIn, uint256 errorAbsOut) public view {
        for (uint256 i = 0; i < holders.length; i++) {
            if (!_isNonRebasingAccount(holders[i])) {
                (uint256 creditBalance,,) = oeth.creditsBalanceOfHighres(holders[i]);
                uint256 creditPerToken = oeth.rebasingCreditsPerTokenHighres();
                assertApproxEqAbs(
                    creditBalance.divPrecisely(creditPerToken),
                    oeth.balanceOf(holders[i]),
                    errorAbsIn,
                    "balanceOf == _creditBalances / _rebasingCreditsPerToken, for each rebasedOptIn user"
                );
            } else {
                (uint256 creditBalance,,) = oeth.creditsBalanceOfHighres(holders[i]);
                uint256 creditPerToken = oeth.nonRebasingCreditsPerToken(holders[i]);
                assertApproxEqAbs(
                    creditBalance.divPrecisely(creditPerToken),
                    oeth.balanceOf(holders[i]),
                    errorAbsOut,
                    "balanceOf == _creditBalances / nonRebasingCreditsPerToken, for each rebasedOptOut user"
                );
            }
        }
    }

    function assert_Invariant_I() public view {
        for (uint256 i = 0; i < holders.length; i++) {
            if (!_isNonRebasingAccount(holders[i]) && oethHandler.rebaseInOrOut(holders[i])) {
                assertTrue(
                    oeth.rebaseState(holders[i]) == OUSD.RebaseOptions.OptIn,
                    "rebaseState == RebaseState.OPT_IN, for each rebasedOptIn user"
                );
            } else if (_isNonRebasingAccount(holders[i]) && oethHandler.rebaseInOrOut(holders[i])) {
                assertTrue(
                    oeth.rebaseState(holders[i]) == OUSD.RebaseOptions.OptOut,
                    "rebaseState == RebaseState.OPT_OUT, for each rebasedOptOut user"
                );
            }
        }
    }

    function _sumUsersBalance() public view returns (uint256 sum) {
        for (uint256 i = 0; i < holders.length; i++) {
            sum += oeth.balanceOf(holders[i]);
        }
        sum += oeth.balanceOf(dead);
        sum += oeth.balanceOf(dead2);
    }

    function _sumUsersBalanceOut() public view returns (uint256 sum) {
        for (uint256 i = 0; i < holders.length; i++) {
            if (_isNonRebasingAccount(holders[i])) {
                sum += oeth.balanceOf(holders[i]);
            }
        }
        sum += oeth.balanceOf(dead2);
    }

    function _sumCreditBalanceIn() public view returns (uint256 sum) {
        for (uint256 i = 0; i < holders.length; i++) {
            if (!_isNonRebasingAccount(holders[i])) {
                (uint256 creditBalance_,,) = oeth.creditsBalanceOfHighres(holders[i]);
                sum += creditBalance_;
            }
        }
        (uint256 creditBalance,,) = oeth.creditsBalanceOfHighres(dead);
        sum += creditBalance;
    }

    function _isNonRebasingAccount(address _user) internal view returns (bool) {
        return oeth.nonRebasingCreditsPerToken(_user) > 0;
    }
}
