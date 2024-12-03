// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Foundry
import {StdUtils} from "forge-std/StdUtils.sol";

// Utils
import {Setup} from "./Setup.sol";
import {Utils} from "./Utils.sol";

// Contracts
import {OUSD} from "origin/token/OUSD.sol";

/// @title Properties contract
/// @notice Use to store all the properties (invariants) of the system.
abstract contract Properties is Setup, StdUtils, Utils {
    //////////////////////////////////////////////////////
    /// --- GHOST VARIABLES
    //////////////////////////////////////////////////////
    bool public ghost_bi_A = true;
    bool public ghost_bi_B = true;
    bool public ghost_bi_C = true;
    bool public ghost_ri_B = true;
    bool public ghost_mi_B = true;
    bool public ghost_mi_D = true;
    bool public ghost_mi_E = true;
    bool public ghost_mi_F = true;
    bool public ghost_mi_G = true;

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
    // Invariant A: When transfer(), rebaseOptIn(), rebaseOptOut(), delegateYield(), undelegateYield(), totalSupplyBefore == totalSupplyAfter.
    // Invariant B: When transfer(from, to, amount), balanceBefore(from) == balanceAfter(from) + amount (checked in handlers)
    // Invariant C: When transfer(from, to, amount), balanceBefore(to) + amount == balanceAfter(to) (checked in handlers)
    // Invariant D: ∀ user, ∑balanceOf(user) <= totalSupply
    // Invariant E: ∀ user ∈ [rebaseState == StdNonRebasing], ∑balanceOf(user) == nonRebasingSupply (± 1 wei)
    // Invariant F: ∀ user ∈ [rebaseState == NotSet || StdRebasing || YieldDelegationTarget], ∑creditBalances(user) == rebasingCredits (± 2e9 * #users * #call wei)
    // Invariant G: ∀ user, balanceOf(user) == _creditBalances[account] * 1e18 / (alternativeCreditsPerToken[account] > 0 ? alternativeCreditsPerToken[account] : _rebasingCreditsPerToken) - (yieldFrom[account] == 0 ? 0 : _creditBalances[yieldFrom[account]])

    // --- Rebasing invariants ---
    // Invariant A: totalSupply >= nonRebasingCredits + (rebasingCredits / rebasingCreditsPerToken)
    // Invariant B: When changeSupply(newValue), totalSupply == newValue (checked in handlers)
    // Invariant C: ∀ user ∈ [rebaseState == StdNonRebasing || YieldDelegationSource], if transfer(amount) || mint(amount) || burn(amount) && amount != 0, balanceOfBefore(user) != balanceOfAfter(user) (checked in handlers)
    // Note for Invariant C: This is already checked with Balance Invariant B_C and Miscallaneous Invariant E_F, so I will not implement it here.
    // Invariant D: rebasingCreditPerToken <= 1e27

    // --- Miscellaneous invariants ---
    // Invariant A: ∀ user ∈ [rebaseState == StdRebasing], alternativeCreditsPerToken[user] == 0
    // Invariant B: When rebaseOptIn(), balanceBefore(user) == balanceAfter(user) (checked in handlers)
    // Invariant C: ∀ user ∈ [rebaseState == StdNonRebasing], alternativeCreditsPerToken[user] == 1e18
    // Invariant D: When rebaseOptOut(), balanceBefore(user) == balanceAfter(user) (checked in handlers)
    // Invariant E: When mint(to, amount), balanceBefore(to) + amount == balanceAfter(to) (checked in handlers)
    // Invariant F: When burn(from, amount), balanceBefore(from) == balanceAfter(from) + amount (checked in handlers)
    // Invariant G: When transfer(from, to), ∀ user /∈ [from, to], balanceBefore == balanceAfter (checked in handlers)

    //////////////////////////////////////////////////////
    /// --- ACCOUNT INVARIANTS
    //////////////////////////////////////////////////////
    function property_account_A() public view returns (bool) {
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

    function property_account_B() public view returns (bool) {
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

    function property_account_C() public view returns (bool) {
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

    function property_account_D() public view returns (bool) {
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

    function property_account_E() public view returns (bool) {
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
    function property_balance_A() public view returns (bool) {
        return ghost_bi_A;
    }

    function property_balance_B() public view returns (bool) {
        return ghost_bi_B;
    }

    function property_balance_C() public view returns (bool) {
        return ghost_bi_C;
    }

    function property_balance_D() public view returns (bool) {
        uint256 sum;
        uint256 len = users.length;
        for (uint256 i; i < len; i++) {
            sum += oeth.balanceOf(users[i]);
        }

        sum += oeth.balanceOf(dead);

        return gte(oeth.totalSupply(), sum);
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

        return gte(oeth.nonRebasingSupply() + 2, sum);
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

        return approxEqAbs(sum, oeth.rebasingCreditsHighres(), users.length * 2e9 * 10);
    }

    function property_balance_G() public view returns (bool) {
        for (uint256 i; i < users.length; i++) {
            address user = users[i];
            (uint256 creditBalance,,) = oeth.creditsBalanceOfHighres(user);
            (uint256 creditBalanceYieldFrom,,) = oeth.creditsBalanceOfHighres(oeth.yieldFrom(user));

            uint256 alternativeCreditsPerToken = oeth.nonRebasingCreditsPerToken(user);
            if (
                approxEqAbs(
                    oeth.balanceOf(user),
                    creditBalance * 1e18
                        / (
                            alternativeCreditsPerToken > 0
                                ? alternativeCreditsPerToken
                                : oeth.rebasingCreditsPerTokenHighres()
                        ) - (oeth.yieldFrom(user) == address(0) ? 0 : creditBalanceYieldFrom),
                    0
                )
            ) {
                continue;
            } else {
                return false;
            }
        }

        return true;
    }

    //////////////////////////////////////////////////////
    /// --- REBASING INVARIANTS
    //////////////////////////////////////////////////////
    function property_rebasing_A() public view returns (bool) {
        return
            oeth.totalSupply() >= oeth.nonRebasingSupply() + (oeth.rebasingCredits() / oeth.rebasingCreditsPerToken());
    }

    function property_rebasing_B() public view returns (bool) {
        return ghost_ri_B;
    }

    function property_rebasing_D() public view returns (bool) {
        return lte(oeth.rebasingCreditsPerToken(), 1e27);
    }

    //////////////////////////////////////////////////////
    /// --- MISCALLANEOUS INVARIANTS
    //////////////////////////////////////////////////////
    function property_miscallaneous_A() public view returns (bool) {
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

    function property_miscallaneous_B() public view returns (bool) {
        return ghost_mi_B;
    }

    function property_miscallaneous_C() public view returns (bool) {
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

    function property_miscallaneous_D() public view returns (bool) {
        return ghost_mi_D;
    }

    function property_miscallaneous_E() public view returns (bool) {
        return ghost_mi_E;
    }

    function property_miscallaneous_F() public view returns (bool) {
        return ghost_mi_F;
    }

    function property_miscallaneous_G() public view returns (bool) {
        return ghost_mi_G;
    }
}
