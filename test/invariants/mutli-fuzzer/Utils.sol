// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

abstract contract Utils {
    event log_named_uint256(string name, uint256 value);

    function absDiff(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a : b;
    }
}
