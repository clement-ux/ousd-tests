// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Foundry
import {StdUtils} from "forge-std/StdUtils.sol";

// Utils
import {Setup} from "./Setup.sol";

// Contracts
import {OUSD} from "origin/token/OUSD.sol";

/// @title Properties contract
/// @notice Use to store all the properties (invariants) of the system.
abstract contract Properties is Setup, StdUtils {
    //////////////////////////////////////////////////////
    /// --- PROPERTIES
    //////////////////////////////////////////////////////

    // --- Account invariants ---
    // Invariant A: ∀ user ∈ [alternativeCreditsPerToken == 0]   , rebaseState == NotSet || StdRebasing || YieldDelegationTarget
    // Invariant B: ∀ user ∈ [alternativeCreditsPerToken == 1e18], rebaseState == StdNonRebasing || YieldDelegationSource
    // Invariant C: ∀ user, alternativeCreditsPerToken == 0 || 1e18 (and no other possible value)
    // Invariant D: ∀ user ∈ [rebaseState == YieldDelegationSource], yieldTo[user]   != address(0)
    // Invariant E: ∀ user ∈ [rebaseState == YieldDelegationTarget], yieldFrom[user] != address(0)
    // Invariant F: ∀ yieldFrom[user] != address(0), yieldTo[yieldFrom[user]] == user

    // --- Balance invariants ---
    // Invariant A:
    // Invariant B: When transfer(from, to, amount), balanceBefore(from) == balanceAfter(from) + amount (checked in handlers)
    // Invariant C: When transfer(from, to, amount), balanceBefore(to) + amount == balanceAfter(to) (checked in handlers)
    // Invariant D: ∀ user, ∑balanceOf(user) <= totalSupply
    // Invariant E: ∀ user ∈ [rebaseState == StdNonRebasing], ∑balanceOf(user) == nonRebasingSupply
    // Invariant F: ∀ user ∈ [rebaseState == NotSet || StdRebasing || YieldDelegationTarget], ∑creditBalances(user) == rebasingCredits
    // Invariant G: ∀ user, balanceOf(user) == _creditBalances[account] * (alternativeCreditsPerToken[account] > 0 ? alternativeCreditsPerToken[account] : _rebasingCreditsPerToken) - (yieldFrom[account] == 0 ? 0 : _creditBalances[yieldFrom[account]])

    // --- Rebasing invariants ---
    // Invariant A: totalSupply >= nonRebasingCredits + (rebasingCredits / rebasingCreditsPerToken)
    // Invariant B: When changeSupply(newValue), totalSupply == newValue (checked in handlers)
    // Invariant C: ∀ user ∈ [rebaseState == StdNonRebasing || YieldDelegationSource], if transfer(amount) || mint(amount) || burn(amount) && amount != 0, balanceOfBefore(user) != balanceOfAfter(user) (checked in handlers)

    // --- Miscellaneous invariants ---
    // Invariant A: ∀ user ∈ [rebaseState == StdRebasing], alternativeCreditsPerToken[user] == 0
    // Invariant B: When rebaseOptIn(), balanceBefore(user) == balanceAfter(user) (checked in handlers)
    // Invariant C: ∀ user ∈ [rebaseState == StdNonRebasing], alternativeCreditsPerToken[user] == 1e18
    // Invariant D: When rebaseOptOut(), balanceBefore(user) == balanceAfter(user) (checked in handlers)
    // Invariant E: When mint(to, amount), balanceBefore(to) + amount == balanceAfter(to) (checked in handlers)
    // Invariant F: When burn(from, amount), balanceBefore(from) == balanceAfter(from) + amount (checked in handlers)

    //////////////////////////////////////////////////////
    /// --- ACCOUNT INVARIANTS
    //////////////////////////////////////////////////////
    function property_A() public view returns (bool) {
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            address user_ = users[i];

            if (oeth.nonRebasingCreditsPerToken(user_) == 0) {
                OUSD.RebaseOptions state = oeth.rebaseState(user_);

                if (
                    state == OUSD.RebaseOptions.NotSet || state == OUSD.RebaseOptions.StdRebasing
                        || state == OUSD.RebaseOptions.YieldDelegationTarget
                ) {
                    continue;
                } else {
                    return false;
                }
            }
        }

        return true;
    }

    function property_B() public view returns (bool) {
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            address user_ = users[i];

            if (oeth.nonRebasingCreditsPerToken(user_) == 1e18) {
                OUSD.RebaseOptions state = oeth.rebaseState(user_);

                if (state == OUSD.RebaseOptions.StdNonRebasing || state == OUSD.RebaseOptions.YieldDelegationSource) {
                    continue;
                } else {
                    return false;
                }
            }
        }

        return true;
    }

    function property_C() public view returns (bool) {
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            address user_ = users[i];
            uint256 alternativeCreditsPerToken = oeth.nonRebasingCreditsPerToken(user_);
            if (alternativeCreditsPerToken != 0 && alternativeCreditsPerToken != 1e18) {
                return false;
            }
        }

        return true;
    }

    function property_D() public view returns (bool) {
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            address user_ = users[i];

            if (oeth.rebaseState(user_) == OUSD.RebaseOptions.YieldDelegationSource) {
                if (oeth.yieldTo(user_) != address(0)) {
                    continue;
                } else {
                    return false;
                }
            } else if (oeth.rebaseState(user_) == OUSD.RebaseOptions.YieldDelegationTarget) {
                if (oeth.yieldFrom(user_) != address(0)) {
                    continue;
                } else {
                    return false;
                }
            }
        }

        return true;
    }

    function property_E() public view returns (bool) {
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            address user_ = users[i];

            if (oeth.yieldFrom(user_) != address(0)) {
                if (oeth.yieldTo(oeth.yieldFrom(user_)) == user_) {
                    continue;
                } else {
                    return false;
                }
            }
        }

        return true;
    }

    //////////////////////////////////////////////////////
    /// --- BALANCE INVARIANTS
    //////////////////////////////////////////////////////
    function property_balance_A() public view returns (bool) {}

    function property_balance_B() public pure returns (bool) {
        // checked in handlers
        return true;
    }

    function property_balance_C() public pure returns (bool) {
        // checked in handlers
        return true;
    }

    function property_balance_D() public view returns (bool) {
        uint256 sum;
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            sum += oeth.balanceOf(users[i]);
        }

        sum += oeth.balanceOf(dead);
        sum += oeth.balanceOf(dead2);

        return sum <= oeth.totalSupply();
    }

    function property_balance_E() public view returns (bool) {
        uint256 sum;
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            address user_ = users[i];

            if (oeth.rebaseState(user_) == OUSD.RebaseOptions.StdNonRebasing) {
                sum += oeth.balanceOf(user_);
            }
        }

        sum += oeth.balanceOf(dead2);

        return sum <= oeth.nonRebasingSupply();
    }

    function property_balance_F() public view returns (bool) {
        uint256 sum;
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            address user_ = users[i];

            OUSD.RebaseOptions state = oeth.rebaseState(user_);
            if (
                state == OUSD.RebaseOptions.NotSet || state == OUSD.RebaseOptions.StdRebasing
                    || state == OUSD.RebaseOptions.YieldDelegationTarget
            ) {
                (uint256 _creditBalance,,) = oeth.creditsBalanceOfHighres(user_);
                sum += _creditBalance;
            }
        }

        (uint256 creditBalance,,) = oeth.creditsBalanceOfHighres(dead);
        sum += creditBalance;

        return sum <= oeth.rebasingCredits();
    }

    //////////////////////////////////////////////////////
    /// --- REBASING INVARIANTS
    //////////////////////////////////////////////////////
    function property_rebasing_A() public view returns (bool) {
        return
            oeth.totalSupply() >= oeth.nonRebasingSupply() + (oeth.rebasingCredits() / oeth.rebasingCreditsPerToken());
    }

    function property_rebasing_B() public pure returns (bool) {
        // checked in handlers
        return true;
    }

    function property_rebasing_C() public pure returns (bool) {
        // checked in handlers
        return true;
    }

    //////////////////////////////////////////////////////
    /// --- MISCALLANEOUS INVARIANTS
    //////////////////////////////////////////////////////
    function property_other_A() public view returns (bool) {
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            address user_ = users[i];

            if (oeth.rebaseState(user_) == OUSD.RebaseOptions.StdRebasing) {
                if (oeth.nonRebasingCreditsPerToken(user_) == 0) {
                    continue;
                } else {
                    return false;
                }
            }
        }

        return true;
    }

    function property_other_B() public pure returns (bool) {
        // checked in handlers
        return true;
    }

    function property_other_C() public view returns (bool) {
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            address user_ = users[i];

            if (oeth.rebaseState(user_) == OUSD.RebaseOptions.StdNonRebasing) {
                if (oeth.nonRebasingCreditsPerToken(user_) == 1e18) {
                    continue;
                } else {
                    return false;
                }
            }
        }

        return true;
    }

    function property_other_D() public pure returns (bool) {
        // checked in handlers
        return true;
    }

    function property_other_E() public pure returns (bool) {
        // checked in handlers
        return true;
    }

    function property_other_F() public pure returns (bool) {
        // checked in handlers
        return true;
    }
}
