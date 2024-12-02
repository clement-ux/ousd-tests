// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Utils
import {TargetFunctions} from "./TargetFunctions.sol";

// configure solc-select to use compiler version:
// solc-select install 0.8.23
// solc-select use 0.8.23
//
// run from base project directory with:
// echidna . --contract EchidnaFuzzer --config echidna.yaml
contract EchidnaFuzzer is TargetFunctions {
    constructor() {
        setup();

        // Mint some OETH to dead address to avoid empty contract
        hevm.prank(address(vault));
        oeth.mint(dead, 1 ether);
    }
}
