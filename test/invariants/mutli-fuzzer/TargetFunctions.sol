// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Foundry
import {console} from "forge-std/Console.sol";

// Utils
import {Properties} from "./Properties.sol";

// Contracts
import {OUSD} from "origin/token/OUSD.sol";

/// @title TargetFunctions contract
/// @notice Use to handle all calls to the tested contract.
abstract contract TargetFunctions is Properties {
    //////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////
    // This DOS_CHECK constant is used to check if the contract is able to handle the situation where it should revert.
    // If true, no transaction should revert. If false, some transaction might revert.
    bool public constant DOS_CHECK = false;
    uint256 public constant MAX_SUPPLY = type(uint128).max;
    uint256 public constant MAX_SUPPLY_CHANGE_PCT = 1e18; // 100%

    //////////////////////////////////////////////////////
    /// --- HANDLERS
    //////////////////////////////////////////////////////
    /// @notice Handler to mint a random amount of OETH to a random user.
    /// @param _account The index of the user to mint to.
    /// @param _amount The amount to mint. Maximum value is 2^96 - 1 (approx equal to 79B ether).
    /// We could have use higher uint type, but it doesn't match real world usage.
    /// We could have use uint88 (approx equal to 309M ether), but it's slightly too low.
    function handler_mint(uint8 _account, uint96 _amount) public {
        // Select a random users among the list.
        address user = users[_account % users.length];

        if (oeth.totalSupply() + _amount >= MAX_SUPPLY && DOS_CHECK) {
            console.log("OETH function: mint() \t from: Skipped because: Max supply reached");
            return;
        }

        // Prank the vault address.
        hevm.prank(address(vault));
        oeth.mint(user, _amount);

        // Idea: use a color when the value is high.
        console.log("OETH function: mint() \t from: %s \t to: %s \t amount: %18e", "Null", names[user], _amount);
    }

    /// @notice Handler to burn a random amount of OETH from a random user.
    /// @param _account The index of the user to burn from.
    /// @param _amount The amount to burn. The goal here is (when no t is DOS_CHECK mode), to try to burn sometime more
    /// that the user has, to see how the contract handle it. Under normal conditions it should revert.
    /// But in the situtation where the contract doesn't revert, invariants will catch it.
    /// Using uint96 instead of uint256 allow us to reduce reverting call. Because user can mint max 2^96 - 1.
    /// The higher the _amount uint type, the higher the chance to revert, but a too low value will not deeply test the contract.
    function handler_burn(uint8 _account, uint96 _amount) public {
        // Select random user with balance > 0.
        address user;
        uint256 balanceOf;
        uint256 len = users.length;
        for (uint256 i = _account; i < _account + len; i++) {
            uint256 balanceOf_ = oeth.balanceOf(users[i % len]);
            if (balanceOf_ > 0) {
                user = users[i % len];
                balanceOf = balanceOf_;
                break;
            }
        }

        // If no user found, Todo: add i.e.
        if (user == address(0)) {
            console.log("OETH function: burn() \t from: Skipped because: No user found");
            // Todo: Maybe it could be interesting to try to jump into another handler instead of return.
            return;
        }

        // Bound amount to burn.
        // Clamped between 1, because burning 0 is useless as return early and doesn't perfom any action.
        // Clamped between balanceOf, because burning more than the balance should revert.
        if (DOS_CHECK) _amount = uint96(_bound(_amount, 1, balanceOf));

        // Prank the vault address.
        hevm.prank(address(vault));
        oeth.burn(user, _amount);

        // Idea: use a color when the value is high.
        console.log("OETH function: burn() \t from: %s \t to: %s \t amount: %18e", names[user], "Null", _amount);
    }

    /// @notice Handler to change the totalSupply of OETH.
    /// @param _pctChange The percentage change to apply to the totalSupply.
    /// Clamped between 0.000000000000000001% and MAX_SUPPLY_CHANGE_PCT.
    function handler_changeSupply(uint64 _pctChange) public {
        // Fetch and cache totalSupply.
        uint256 totalSupply = oeth.totalSupply();

        // Note: for DOS_CHECK
        // If we are checking DOS, we are aware of the situation so we can return early.
        // If we are not checking DOS, we can let the require revert.
        // If totalSupply is null, require will revert.
        if (totalSupply == 0 && DOS_CHECK) {
            console.log("OETH function: changeSupply() \t from: Skipped because totalSupply == 0");
            return;
        }

        // If totalSupply is equal to nonRebasingSupply, div will fail.
        if (min(oeth.totalSupply(), MAX_SUPPLY) == oeth.nonRebasingSupply() && DOS_CHECK) {
            console.log("OETH function: changeSupply() \t from: Skipped because totalSupply == nonRebasingSupply");
            return;
        }

        // If totalSupply - nonRebasingSupply > rebasingCreditsHighres * 1e18, div be rounded to 0 and require will revert.
        if (
            min(oeth.totalSupply(), MAX_SUPPLY) - oeth.nonRebasingSupply() > oeth.rebasingCreditsHighres() * 1e18
                && DOS_CHECK
        ) {
            console.log(
                "OETH function: changeSupply() \t from: Skipped because totalSupply - nonRebasingSupply > rebasingCreditsHighres"
            );
            return;
        }

        // If rebasingCredits_ == 0, rebasingCreditsPerToken_ will be 0 too and require will revert.
        if (oeth.rebasingCreditsHighres() == 0 && DOS_CHECK) {
            console.log("OETH function: changeSupply() \t from: Skipped because rebasingCreditsHighres == 0");
            return;
        }

        // Bound the percentage change between 0.000000000000000001% and 100%.
        _pctChange = uint64(_bound(_pctChange, 1, MAX_SUPPLY_CHANGE_PCT));
        // Calculate the new totalSupply.
        uint256 newTotalSupply = totalSupply * (1e18 + _pctChange) / 1e18;

        // Prank the vault address.
        hevm.prank(address(vault));
        oeth.changeSupply(newTotalSupply);

        // Idea: use a color when the percentage change is high.
        console.log(
            "OETH function: changeSupply()  from: %18e \t to: %18e (%16e%)", totalSupply, newTotalSupply, _pctChange
        );
    }

    /// @notice Handler to transfer a random amount of OETH from a random user to another random user.
    /// @param _from The index of the user to transfer from.
    /// @param _to The index of the user to transfer to.
    /// @param _amount The amount to transfer. The goal here is (when no t is DOS_CHECK mode),
    /// to try to transfer sometime more than the user has.
    function handler_transfer(uint8 _from, uint8 _to, uint96 _amount) public {
        // Select random user with balance > 0.
        address from;
        uint256 balanceOf;
        uint256 len = users.length;
        for (uint256 i = _from; i < _from + len; i++) {
            uint256 balanceOf_ = oeth.balanceOf(users[i % len]);
            if (balanceOf_ > 0) {
                from = users[i % len];
                balanceOf = balanceOf_;
                break;
            }
        }

        // If no user found, i.e. no user have tokens.
        if (from == address(0)) {
            console.log("OETH function: transfer() \t from: Skipped because: No user found");
            return;
        }

        // This should be the only case where transfer can revert.
        if (DOS_CHECK) _amount = uint96(_bound(_amount, 0, balanceOf));

        // User can send to himself.
        address to = users[_to % users.length];

        hevm.prank(from);
        oeth.transfer(to, _amount);

        console.log("OETH function: transfer() \t from: %s \t to: %s \t amount: %18e", names[from], names[to], _amount);
    }

    /// @notice Handler to rebaseOptIn a random user.
    /// @param _account The index of the user to rebaseOptIn.
    function handler_rebaseOptIn(uint8 _account) public {
        // Select random user with:
        // alternativeCreditsPerToken[_account] > 0 || balance == 0
        // &&
        // state == RebaseOptions.StdNonRebasing || state == RebaseOptions.NotSet,
        address user;
        uint256 len = users.length;
        for (uint256 i = _account; i < _account + len; i++) {
            address _user = users[i % len];
            OUSD.RebaseOptions state = oeth.rebaseState(_user);
            if (
                (oeth.nonRebasingCreditsPerToken(_user) > 0 || oeth.balanceOf(_user) == 0)
                    && (state == OUSD.RebaseOptions.StdNonRebasing || state == OUSD.RebaseOptions.NotSet)
            ) {
                user = _user;
                break;
            }
        }

        // If no user found, Todo: add i.e.
        // Because there is no restriction that address 0 can rebaseOptIn, we always prevent it, no matter DOS_CHECK.
        if (user == address(0)) {
            console.log("OETH function: rebaseOptIn() \t from: Skipped because: No user found");
            return;
        }

        // RebaseOptIn
        hevm.prank(user);
        oeth.rebaseOptIn();

        console.log("OETH function: rebaseOptIn() \t from: %s", names[user]);
    }

    /// @notice Handler to rebaseOptOut a random user.
    /// @param _account The index of the user to rebaseOptOut.
    function handler_rebaseOptOut(uint8 _account) public {
        // Select a random user with:
        // alternativeCreditsPerToken[_account] == 0
        // &&
        // state == RebaseOptions.StdRebasing || state == RebaseOptions.NotSet
        address user;
        uint256 len = users.length;
        for (uint256 i = _account; i < _account + len; i++) {
            address _user = users[i % len];
            OUSD.RebaseOptions state = oeth.rebaseState(_user);
            if (
                oeth.nonRebasingCreditsPerToken(_user) == 0
                    && (state == OUSD.RebaseOptions.StdRebasing || state == OUSD.RebaseOptions.NotSet)
            ) {
                user = _user;
                break;
            }
        }

        // If no user found, Todo: add i.e.
        // Because there is no restriction that address 0 can rebaseOptOut, we always prevent it, no matter DOS_CHECK.
        if (user == address(0)) {
            console.log("OETH function: rebaseOptOut()  from: Skipped because: No user found");
            return;
        }

        // RebaseOptOut
        hevm.prank(user);
        oeth.rebaseOptOut();

        console.log("OETH function: rebaseOptOut()  from: %s", names[user]);
    }

    //////////////////////////////////////////////////////
    /// --- HELPERS
    //////////////////////////////////////////////////////
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // Todo: List of handler to implement
    //
    // --- Vault Actions
    // - mint() (done)
    // - burn() (done)
    // - changeSupply() (done)
    //
    // --- Users Actions
    // - transfer() (done)
    // - rebaseOptIn() (done)
    // - rebaseOptOut() (done)
    //
    // --- Governance Actions
    // - delegateYield()
    // - undelegateYield()
}
