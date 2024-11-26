// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Test imports
import {Base_Test_} from "./Base.sol";

// Contracts
import {OETH} from "origin/token/OETH.sol";
import {OETHProxy} from "origin/proxies/Proxies.sol";

// Interfaces
import {IVault} from "origin/interfaces/IVault.sol";

abstract contract Shared_Test_ is Base_Test_ {
    //////////////////////////////////////////////////////
    /// --- STORAGE
    //////////////////////////////////////////////////////
    address[] public users;

    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public virtual override {
        // 1. Setup a realistic test environnement.
        _setUpRealisticEnvironnement();

        // 2. Create user.
        _createUsers();

        // 3. Deploy mocks. We don't have mocks at the moment.
        // _deployMocks();

        // 4. Deploy contracts.
        _deployContracts();

        // 5. Label addresses.
        _labelAll();
    }

    function _setUpRealisticEnvironnement() private {
        vm.roll(21000000); // block number
        vm.warp(1730419200); // timestamp
    }

    function _createUsers() private {
        // Users with role
        deployer = makeAddr("Deployer");
        governor = makeAddr("Governor");
        vault = IVault(makeAddr("Vault"));

        // Random users
        alice = makeAddr("Alice");
        bob = makeAddr("Bob");
        charlie = makeAddr("Charlie");
        dave = makeAddr("Dave");
        eve = makeAddr("Eve");
        frank = makeAddr("Frank");
        dead = makeAddr("Dead");
        dead2 = makeAddr("Dead2");

        // Add users to the list
        users.push(alice);
        users.push(bob);
        users.push(charlie);
        users.push(dave);
        users.push(eve);
        users.push(frank);
    }

    function _deployContracts() private {
        vm.startPrank(deployer);

        // 1. Deploy proxy.
        oethProxy = new OETHProxy();

        // 2. Deploy OETH implementation.
        oeth = new OETH();

        // 3. Initialize proxy.
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,uint256)", address(vault), 1e27
        );

        oethProxy.initialize(address(oeth), governor, data);

        // 4. Set proxy as OETH.
        oeth = OETH(address(oethProxy));

        vm.stopPrank();
    }
}
