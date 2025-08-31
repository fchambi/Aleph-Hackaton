// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Types
 * @dev Shared types and structures for MicroCredit DAO
 */
library Types {
    /**
     * @dev Loan status enumeration
     */
    enum LoanStatus {
        Requested,  // 0: Loan requested by borrower
        Approved,   // 1: Loan approved by manager
        Drawn,      // 2: Loan amount drawn by borrower
        Repaid,     // 3: Loan fully repaid
        Defaulted   // 4: Loan defaulted
    }

    /**
     * @dev Pool configuration parameters
     */
    struct PoolParams {
        uint16 interestRateBps;      // Interest rate in basis points (e.g., 500 = 5% annual simple)
        uint16 tenorDays;            // Loan term in days
        uint16 maxLoanToPoolBps;     // Maximum loan amount as % of pool assets (e.g., 5000 = 50%)
        uint16 reserveFactorBps;     // % of interest that goes to Treasury
        uint16 minCreditScore;       // Minimum credit score required (0-100)
    }

    /**
     * @dev Loan structure
     */
    struct Loan {
        address borrower;     // Borrower address
        uint256 principal;    // Principal amount
        uint256 createdAt;    // Timestamp when loan was created
        uint256 drawnAt;      // Timestamp when loan was drawn
        uint256 dueAt;        // Timestamp when loan is due
        uint16 rateBps;       // Interest rate in basis points
        uint16 tenorDays;     // Loan term in days
        LoanStatus status;    // Current loan status
    }
}
