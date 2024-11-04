// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Foundry
import {console} from "forge-std/console.sol";

// Handlers
import {BaseHandler} from "./BaseHandler.sol";

// Contracts
import {OETH} from "origin/token/OETH.sol";

// Interfaces
import {IVault} from "origin/interfaces/IVault.sol";

contract OETHHandler is BaseHandler {
    //////////////////////////////////////////////////////
    /// --- STORAGE
    //////////////////////////////////////////////////////
    OETH private oeth;

    IVault private vault;

    uint256 private maxMintable;
    uint256 private maxTotalSupplyIncrease;

    address[] private holders;

    ////////////////////////////////////////////////////
    /// --- VARIABLES FOR INVARIANT ASSERTIONS
    ////////////////////////////////////////////////////
    uint256 public sum_of_mint;
    uint256 public sum_of_burn;
    uint256 public sum_of_transfer;

    mapping(address => uint256) public sum_of_send;
    mapping(address => uint256) public sum_of_receive;

    //////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    //////////////////////////////////////////////////////
    constructor(
        address _oeth,
        address[] memory _holders,
        IVault _vault,
        uint256 _maxMintable,
        uint256 _maxTotalSupplyIncrease
    ) {
        oeth = OETH(_oeth);

        require(_holders.length > 0, "OETHHandler: No holders");
        holders = _holders;

        vault = _vault;

        maxMintable = _maxMintable;
        maxTotalSupplyIncrease = _maxTotalSupplyIncrease;
    }

    ////////////////////////////////////////////////////
    /// --- ACTIONS
    ////////////////////////////////////////////////////
    function mint(uint256 _seed) external {
        numberOfCalls["oeth.mint"]++;

        // Select a random user
        // As the max mintable amount is 100M, we can mint a lot of time before reaching the limit
        address user = holders[_seed % holders.length];

        uint256 amountToMint = _bound(_seed, 0, maxMintable);

        // Mint
        vm.prank(address(vault));
        oeth.mint(user, amountToMint);

        // Update sum of mint
        sum_of_mint += amountToMint;

        // Log
        console.log("OETHHandler.mint(%18e), %s", amountToMint, names[user]);
    }

    function burn(uint256 _seed) external {
        numberOfCalls["oeth.burn"]++;

        // Select a valid random user
        address user;
        uint256 balanceOf;
        uint256 len = holders.length;
        uint256 initial = _seed % len;
        for (uint256 i = initial; i < initial + len; i++) {
            uint256 balanceOf_ = oeth.balanceOf(holders[i % len]);
            if (balanceOf_ > 0) {
                user = holders[i % len];
                balanceOf = balanceOf_;
                break;
            }
        }

        // If no user found, i.e., all user already maxed out mintable amount, skip
        if (user == address(0)) {
            numberOfCallsSkipped["oeth.burn"]++;
            console.log("OETHHandler.burn: No user found");
            return;
        }

        uint256 amountToBurn = _bound(_seed, 1, balanceOf);

        // Non rebasing supply can be lower than user balance, weird but possible
        // Todo: investigate why
        if (oeth.balanceOf(user) > oeth.nonRebasingSupply()) {
            numberOfCallsSkipped["oeth.burn"]++;
            console.log("OETHHandler.burn: Non rebasing supply < user balance");
            return;
        }

        // Burn
        vm.prank(address(vault));
        oeth.burn(user, amountToBurn);

        // Update sum of mint
        sum_of_burn += amountToBurn;

        // Log
        console.log("OETHHandler.burn(%18e), %s", amountToBurn, names[user]);
    }

    function transfer(uint256 _seed) external {
        numberOfCalls["oeth.transfer"]++;

        // Select a valid random user
        address user;
        uint256 balanceOf;
        uint256 len = holders.length;
        uint256 initial = _seed % len;
        for (uint256 i = initial; i < initial + len; i++) {
            uint256 balanceOf_ = oeth.balanceOf(holders[i % len]);
            if (balanceOf_ > 0) {
                user = holders[i % len];
                balanceOf = balanceOf_;
                break;
            }
        }

        if (user == address(0)) {
            numberOfCallsSkipped["oeth.transfer"]++;
            console.log("OETHHandler.transfer: No user found");
            return;
        }

        uint256 amountToTransfer = _bound(_seed, 0, balanceOf);
        address receiver = holders[_randomize(_seed) % len];

        // Non rebasing supply can be lower than user balance, weird but possible
        // Todo: investigate why
        if (
            (_isNonRebasingAccount(user) && !_isNonRebasingAccount(receiver))
                && (oeth.nonRebasingSupply() < amountToTransfer)
        ) {
            numberOfCallsSkipped["oeth.transfer"]++;
            console.log("OETHHandler.transfer: Non rebasing supply < user balance");
            return;
        }
        // Transfer
        vm.prank(user);
        oeth.transfer(receiver, amountToTransfer);

        // Update sum of transfer and co.
        sum_of_transfer += amountToTransfer;
        sum_of_send[user] += amountToTransfer;
        sum_of_receive[receiver] += amountToTransfer;

        // Log
        console.log("OETHHandler.transfer(%18e), %s -> %s", amountToTransfer, names[user], names[receiver]);
    }

    function rebaseOpt(uint256 _seed) external {
        numberOfCalls["oeth.rebase"]++;

        bool success;
        if ((_seed % 2) == 0) {
            success = _rebaseOptIn(_seed);
            if (!success) {
                success = _rebaseOptOut(_seed);
            }
        } else {
            success = _rebaseOptOut(_seed);
            if (!success) {
                success = _rebaseOptIn(_seed);
            }
        }

        if (!success) {
            numberOfCallsSkipped["oeth.rebase"]++;
            console.log("OETHHandler.rebaseOpt: No user found");
        }
    }

    function changeSupply(uint256 _seed) external {
        numberOfCalls["oeth.changeSupply"]++;

        uint256 totalSupply = oeth.totalSupply();
        if (totalSupply == 0) {
            numberOfCallsSkipped["oeth.changeSupply"]++;
            console.log("OETHHandler.changeSupply: totalSupply null");
            return;
        }
        if (oeth.rebasingCreditsHighres() == 0) {
            numberOfCallsSkipped["oeth.changeSupply"]++;
            console.log("OETHHandler.changeSupply: rebasing credit is null");
            return;
        }

        // Calculate max total supply pct increase.
        uint256 totalSupplyPctIncrease = _bound(_seed, 0, maxTotalSupplyIncrease);

        // Calculate new total supply.
        uint256 newTotalSupply = totalSupply * (1e18 + totalSupplyPctIncrease) / 1e18;

        uint256 nonRebasingSupply = oeth.nonRebasingSupply();

        // Handle situations that might revert.
        if (newTotalSupply <= nonRebasingSupply) {
            numberOfCallsSkipped["oeth.changeSupply"]++;
            console.log("OETHHandler.changeSupply: new totalSupply == nonRebasingSupply");
            return;
        }
        if (min(newTotalSupply, ~uint128(0) - nonRebasingSupply) >= oeth.rebasingCreditsHighres() * 1e18) {
            numberOfCallsSkipped["oeth.changeSupply"]++;
            console.log("OETHHandler.changeSupply: new totalSupply > _rebasingCredits");
            return;
        }

        // Change total supply
        vm.prank(address(vault));
        oeth.changeSupply(newTotalSupply);

        require(newTotalSupply >= totalSupply, "OETHHandler: new totalSupply < totalSupply");

        // Log
        console.log("OETHHandler.changeSupply(%18e), pct increase: %16e%", newTotalSupply, totalSupplyPctIncrease);
    }

    function _rebaseOptIn(uint256 _seed) internal returns (bool) {
        address user;
        uint256 len = holders.length;
        uint256 initial = _seed % len;
        for (uint256 i = initial; i < initial + len; i++) {
            if (_isNonRebasingAccount(holders[i % len])) {
                user = holders[i % len];
                break;
            }
        }

        // If there is no user that can rebaseOptIn, then return false
        if (user == address(0)) return false;

        // nonRebasingSupply can be lower than user balance, weird but possible
        // Todo: investigate why
        if (oeth.balanceOf(user) > oeth.nonRebasingSupply()) {
            return false;
        }

        // RebaseOptIn
        vm.prank(user);
        oeth.rebaseOptIn();

        console.log("OETHHandler.rebaseOptIn(), %s", names[user]);

        return true;
    }

    function _rebaseOptOut(uint256 _seed) internal returns (bool) {
        address user;
        uint256 len = holders.length;
        uint256 initial = _seed % len;
        for (uint256 i = initial; i < initial + len; i++) {
            if (!_isNonRebasingAccount(holders[i % len])) {
                user = holders[i % len];
                break;
            }
        }

        // If there is no user that can rebaseOptOut, then return false
        if (user == address(0)) return false;

        // RebaseOptOut
        vm.prank(user);
        oeth.rebaseOptOut();

        console.log("OETHHandler.rebaseOptOut(), %s", names[user]);

        return true;
    }

    function _isNonRebasingAccount(address _user) internal view returns (bool) {
        return oeth.nonRebasingCreditsPerToken(_user) > 0;
    }

    // Todo:
    // P1:
    // - mint (done)
    // - burn (done)
    // - transfer (done)
    // - rebase optIn (done)
    // - rebase optOut (done)
    // - changeSupply (done)
    // P2:
    // - transferFrom
    // - approve
    // P3:
    // - increaseAllowance
    // - decreaseAllowance
}
