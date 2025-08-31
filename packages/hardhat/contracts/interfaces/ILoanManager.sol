// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../libs/Types.sol";

/**
 * @title ILoanManager
 * @dev Interface for Loan Manager
 */
interface ILoanManager {
    function createLoan(
        address borrower,
        uint256 amount,
        uint16 rateBps,
        uint16 tenorDays
    ) external returns (uint256 loanId);
    
    function approve(uint256 loanId) external;
    function drawdown(uint256 loanId) external;
    
    function currentDebt(uint256 loanId) external view returns (
        uint256 principal,
        uint256 interest,
        uint256 lateFees,
        uint256 total
    );
    
    function repay(uint256 loanId, uint256 amount) external returns (uint256 remaining);
    function markDefault(uint256 loanId) external;
    function getLoan(uint256 loanId) external view returns (Types.Loan memory);
}
