// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Test imports
import {Invariant_Base_Test_} from "test/invariant/BaseInvariant.sol";

// Handlers
import {OETHHandler} from "./handlers/OETHHandler.sol";
import {DistributionHandler} from "./handlers/DistributionHandler.sol";

contract Invariant_Basic_Test_ is Invariant_Base_Test_ {
    //////////////////////////////////////////////////////
    /// --- CONSTANTS && IMMUTABLES
    //////////////////////////////////////////////////////
    uint256 private constant NUM_HOLDERS = 3;
    uint256 private constant RESOLUTION_INCREASE = 1e9;
    uint256 private constant MAX_MINTABLE = 100_000_000 ether; // 100M
    uint256 private constant MAX_TOTALSUPPLY_INCREASE = 10e16; // 10%

    //////////////////////////////////////////////////////
    /// --- STORAGE
    //////////////////////////////////////////////////////
    DistributionHandler private distributionHandler;

    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        // --- Create users ---
        for (uint256 i = 0; i < NUM_HOLDERS; i++) {
            require(users[i] != address(0), "Invariant_Basic_Test_: User not set");
            holders.push(users[i]);
        }

        // --- Deploy Handlers ---
        oethHandler = new OETHHandler(address(oeth), holders, vault, MAX_MINTABLE, MAX_TOTALSUPPLY_INCREASE);

        // --- Set Selectors Weight ---
        oethHandler.setSelectorWeight(oethHandler.mint.selector, 3_000);
        oethHandler.setSelectorWeight(oethHandler.burn.selector, 2_000);
        oethHandler.setSelectorWeight(oethHandler.transfer.selector, 2_000);
        oethHandler.setSelectorWeight(oethHandler.rebaseOpt.selector, 2_000);
        oethHandler.setSelectorWeight(oethHandler.changeSupply.selector, 1_000);

        // --- Set Handlers Weight ---
        address[] memory targetContracts = new address[](1);
        targetContracts[0] = address(oethHandler);

        uint256[] memory weightsDistributorHandler = new uint256[](1);
        weightsDistributorHandler[0] = 10_000; // 100% // OETH Handler

        // --- Deploy Distribution Handler ---
        distributionHandler = new DistributionHandler(targetContracts, weightsDistributorHandler);

        // All call will be done through the distributor, so we set it as the target contract
        targetContract(address(distributionHandler));

        // Mint 1e12 to a user that will keep it and do nothing during all the test
        // This prevent many false positive in the invariant
        vm.prank(address(vault));
        oeth.mint(dead, 1e12 ether);
    }

    function invariant_General() public view {
        assert_Invariant_A();
        assert_Invariant_B({errorAbs: 100 wei});
        assert_Invariant_C({errorAbs: 100 wei});
        assert_Invariant_D({threshhold: 100 wei, errorAbs: 100 wei});
        assert_Invariant_E({errorAbs: 100 wei});
        assert_Invariant_F();
        assert_Invariant_G();
    }
}
