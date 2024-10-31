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

    address[] private holders;

    ////////////////////////////////////////////////////
    /// --- VARIABLES FOR INVARIANT ASSERTIONS
    ////////////////////////////////////////////////////
    uint256 public sum_of_mint;

    //////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    //////////////////////////////////////////////////////
    constructor(
        address _oeth,
        address[] memory _holders,
        IVault _vault,
        uint256 _maxCreditMintable,
        uint256 _resolutionIncrease
    ) {
        oeth = OETH(_oeth);

        require(_holders.length > 0, "OETHHandler: No holders");
        holders = _holders;

        vault = _vault;

        resolutionIncrease = _resolutionIncrease;
        maxCreditMintable = _maxCreditMintable * _resolutionIncrease;
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
            (uint256 credit, uint256 creditPerToken_,) = oeth.creditsBalanceOfHighres(holders[i]);
            if (credit < maxCreditMintable) {
                user = holders[i];
                maxCreditToMint = maxCreditMintable - credit;
                creditPerToken = creditPerToken_;
                break;
            }
        }

        // If no user found, i.e., all user already maxed out mintable amount, skip
        if (user == address(0)) {
            numberOfCallsSkipped["oeth.mint"]++;
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
}
