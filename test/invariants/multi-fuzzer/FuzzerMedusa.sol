// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Utils
import {TargetFunctions} from "./TargetFunctions.sol";

// run from base project directory with:
// medusa fuzz
contract FuzzerMedusa is TargetFunctions {
    constructor() {
        setup();

        // Mint some OETH to dead address to avoid empty contract
        hevm.prank(address(vault));
        oeth.mint(dead, 1 ether);
    }
}
