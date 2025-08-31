// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICreditScoreRegistry
 * @dev Interface for Credit Score Registry
 */
interface ICreditScoreRegistry {
    function getScore(address user) external view returns (uint256);
    function increaseScore(address user, uint256 delta) external;
    function decreaseScore(address user, uint256 delta) external;
}
