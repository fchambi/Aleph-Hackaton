// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../libs/Types.sol";

/**
 * @title IPool
 * @dev Interface for MicroCredit Pool
 */
interface IPool {
    function deposit(uint256 amount) external;
    function withdraw(uint256 shares) external;
    function requestLoan(uint256 amount) external returns (uint256 loanId);
    function approveLoan(uint256 loanId) external;
    function drawdown(uint256 loanId) external;
    function repay(uint256 loanId, uint256 amount) external returns (uint256 remaining);
    function markDefault(uint256 loanId) external;
    function totalAssets() external view returns (uint256);
    function getParams() external view returns (Types.PoolParams memory);
}
