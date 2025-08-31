// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ITreasury
 * @dev Interface for Treasury
 */
interface ITreasury {
    function receiveFees(address token, uint256 amount) external;
    function balanceOf(address token) external view returns (uint256);
    function claim(address token, address to, uint256 amount) external;
}
