// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {Properties} from "./Properties.sol";

/// @title TargetFunctions contract
/// @notice Use to handle all calls to the target functions.
abstract contract TargetFunctions is Properties {
    function handler_A(uint256 x) public {}
}
