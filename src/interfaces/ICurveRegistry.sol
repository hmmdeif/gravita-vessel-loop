// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

interface ICurveRegistry {
    function get_address(uint256) external view returns (address);
}