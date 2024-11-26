// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

// Foundry
import {StdUtils} from "forge-std/StdUtils.sol";

// Utils
import {Setup} from "./Setup.sol";

/// @title Properties contract
/// @notice Use to store all the properties (invariants) of the system.
abstract contract Properties is Setup, StdUtils {}
