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

    uint256 private maxCreditMintable;
    uint256 private resolutionIncrease;
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
        uint256 _maxCreditMintable,
        uint256 _resolutionIncrease,
        uint256 _maxTotalSupplyIncrease
    ) {
        oeth = OETH(_oeth);

        require(_holders.length > 0, "OETHHandler: No holders");
        holders = _holders;

        vault = _vault;

        resolutionIncrease = _resolutionIncrease;
        maxCreditMintable = _maxCreditMintable * _resolutionIncrease;
        maxTotalSupplyIncrease = _maxTotalSupplyIncrease;
    }

    ////////////////////////////////////////////////////
    /// --- ACTIONS
    ////////////////////////////////////////////////////
    function mint(uint256 _seed) external {
        numberOfCalls["oeth.mint"]++;

        // Select a valid random user
        address user;
        uint256 maxCreditToMint;
        uint256 creditPerToken;
        uint256 len = holders.length;
        uint256 initial = _seed % len;
        for (uint256 i = initial; i < initial + len; i++) {
            // Get user credit
            (uint256 credit, uint256 creditPerToken_,) = oeth.creditsBalanceOfHighres(holders[i % len]);
            if (credit < maxCreditMintable) {
                user = holders[i % len];
                maxCreditToMint = maxCreditMintable - credit;
                creditPerToken = creditPerToken_;
                break;
            }
        }

        // If no user found, i.e., all user already maxed out mintable amount, skip
        if (user == address(0)) {
            numberOfCallsSkipped["oeth.mint"]++;
            console.log("OETHHandler.mint: No user found");
            return;
        }

        uint256 maxAmount = maxCreditToMint * 1e18 / creditPerToken; // Some precision loss here, but it's fine for testing.
        uint256 amountToMint = _bound(_seed, 0, maxAmount);

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
                require(success, "OETHHandler: RebaseOptIn/Out failed");
            }
        } else {
            success = _rebaseOptOut(_seed);
            if (!success) {
                success = _rebaseOptIn(_seed);
                require(success, "OETHHandler: RebaseOptOut/In failed");
            }
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
        if ((min(newTotalSupply, ~uint128(0)) - nonRebasingSupply) >= oeth.rebasingCreditsPerTokenHighres() * 1e18) {
            numberOfCallsSkipped["oeth.changeSupply"]++;
            console.log("OETHHandler.changeSupply: new totalSupply > _rebasingCredits");
            return;
        }

        // Change total supply
        vm.prank(address(vault));
        oeth.changeSupply(newTotalSupply);

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
