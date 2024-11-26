// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Foundry
import {Test} from "forge-std/Test.sol";

// Contracts
import {OETH} from "origin/token/OETH.sol";
import {OETHProxy} from "origin/proxies/Proxies.sol";

// Interfaces
import {IVault} from "origin/interfaces/IVault.sol";

abstract contract Base_Test_ is Test {
    //////////////////////////////////////////////////////
    /// --- CONTRACTS & INTERFACES
    //////////////////////////////////////////////////////
    // --- Contracts ---
    OETH public oeth;
    OETHProxy public oethProxy;

    // --- Interfaces ---
    IVault public vault;

    //////////////////////////////////////////////////////
    /// --- GOVERNANCE, MS & EOAS
    //////////////////////////////////////////////////////
    // --- EOAs ---
    address public alice;
    address public bob;
    address public charlie;
    address public dave;
    address public eve;
    address public frank;
    address public dead;
    address public dead2;

    // --- Governance ---
    address public deployer;
    address public governor;

    //////////////////////////////////////////////////////
    /// --- DEFAULT VALUES
    //////////////////////////////////////////////////////
    uint256 public constant DEFAULT_AMOUNT = 1 ether;

    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public virtual {}

    /// @notice Better if called once all contract have been depoyed.
    function _labelAll() internal virtual {
        // Contracts
        vm.label(address(oeth), "OETH");
        vm.label(address(oethProxy), "OETH Proxy");
        vm.label(address(vault), "OETH Vault");

        // Governance, multisig and EOAs
        _labelNotNull(alice, "Alice");
        _labelNotNull(bob, "Bob");
        _labelNotNull(charlie, "Charlie");
        _labelNotNull(dave, "Dave");
        _labelNotNull(eve, "Eve");
        _labelNotNull(frank, "Frank");
        _labelNotNull(dead, "Dead");
        _labelNotNull(dead2, "Dead2");

        _labelNotNull(deployer, "Deployer");
        _labelNotNull(governor, "Governor");
    }

    function _labelNotNull(address _address, string memory _name) internal virtual {
        if (_address != address(0)) vm.label(_address, _name);
    }
}
