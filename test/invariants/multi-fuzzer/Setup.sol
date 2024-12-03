// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Foundry
import {Vm} from "forge-std/Vm.sol";

// Contracts
import {OETH} from "origin/token/OETH.sol";
import {OETHProxy} from "origin/proxies/Proxies.sol";

// Interfaces
import {IVault} from "origin/interfaces/IVault.sol";

/// @title Setup contract
/// @notice Use to store all the global variable and deploy contracts.
abstract contract Setup {
    //////////////////////////////////////////////////////
    /// --- VM
    //////////////////////////////////////////////////////
    Vm internal constant hevm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

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
    address[] public users;
    mapping(address => string) public names;

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

    function setup() internal virtual {
        // 1. Setup a realistic test environnement.
        _setUpRealisticEnvironnement();

        // 2. Create user.
        _createUsers();

        // 3. Deploy mocks. We don't have mocks at the moment.
        // _deployMocks();

        // 4. Deploy contracts.
        _deployContracts();

        // 5. Label addresses.
        //_labelContract();
    }

    function _setUpRealisticEnvironnement() private {
        hevm.roll(21000000); // block number
        hevm.warp(1730419200); // timestamp
    }

    function _createUsers() private {
        // Users with role
        deployer = _makeAddr("Deployer");
        governor = _makeAddr("Governor");
        vault = IVault(_makeAddr("Vault"));

        // Random users
        alice = _makeAddr("Alice");
        bob = _makeAddr("Bob");
        charlie = _makeAddr("Charlie");
        dave = _makeAddr("Dave");
        eve = _makeAddr("Eve");
        frank = _makeAddr("Frank");
        dead = _makeAddr("Dead");
        dead2 = _makeAddr("Dead2");

        // Add users to the list
        users.push(alice);
        users.push(bob);
        users.push(charlie);
        users.push(dave);
        users.push(eve);
        users.push(frank);

        // Add users to name mapping
        names[alice] = "Alice";
        names[bob] = "Bob";
        names[charlie] = "Charlie";
        names[dave] = "Dave";
        names[eve] = "Eve";
        names[frank] = "Frank";
        names[dead] = "Dead";
        names[dead2] = "Dead2";
    }

    function _deployContracts() private {
        // 1. Deploy proxy.
        oethProxy = new OETHProxy();

        // 2. Deploy OETH implementation.
        oeth = new OETH();

        // 3. Initialize proxy.
        bytes memory data = abi.encodeWithSignature("initialize(address,uint256)", address(vault), 1e27);

        oethProxy.initialize(address(oeth), governor, data);

        // 4. Set proxy as OETH.
        oeth = OETH(address(oethProxy));
    }

    function _makeAddr(string memory _name) internal virtual returns (address) {
        address _address = address(uint160(uint256(keccak256(abi.encodePacked(_name)))));

        require(_address != address(0), "Setup: invalid address");

        //hevm.label(_address, _name);
        return _address;
    }

    /// @notice Better if called once all contract have been depoyed.
    function _labelContract() internal virtual {
        // Contracts
        hevm.label(address(oeth), "OETH");
        hevm.label(address(oethProxy), "OETH Proxy");
        hevm.label(address(vault), "OETH Vault");
    }
}
