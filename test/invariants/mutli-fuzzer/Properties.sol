// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {Setup} from "./Setup.sol";

/// @title Properties contract
/// @notice Use to store all the properties (invariants) of the system.
abstract contract Properties is Setup {
    function property_A() public returns (bool) {
        return true;
    }
}
