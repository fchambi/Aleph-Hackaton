// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./libs/Types.sol";
import "./interfaces/ILoanManager.sol";

/**
 * @title LoanManager
 * @dev Manages loan lifecycle and accounting for MicroCredit pools
 */
contract LoanManager is ILoanManager, AccessControl {
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    // Loan counter and mapping
    uint256 private _loanCounter;
    mapping(uint256 => Types.Loan) public loans;
    
    // Events
    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 amount,
        uint16 rateBps,
        uint16 tenorDays
    );
    event LoanStatusChanged(
        uint256 indexed loanId,
        Types.LoanStatus from,
        Types.LoanStatus to
    );
    event LoanAccountingUpdated(
        uint256 indexed loanId,
        uint256 interestPaid,
        uint256 principalPaid,
        uint256 remaining
    );
    
    // Custom errors
    error Unauthorized();
    error InvalidLoanId();
    error InvalidState();
    error AmountZero();
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Create a new loan request
     * @param borrower Address of the borrower
     * @param amount Principal amount requested
     * @param rateBps Interest rate in basis points
     * @param tenorDays Loan term in days
     * @return loanId Unique identifier for the loan
     */
    function createLoan(
        address borrower,
        uint256 amount,
        uint16 rateBps,
        uint16 tenorDays
    ) external onlyRole(POOL_ROLE) returns (uint256 loanId) {
        if (amount == 0) revert AmountZero();
        if (borrower == address(0)) revert InvalidState();
        
        loanId = _loanCounter++;
        
        loans[loanId] = Types.Loan({
            borrower: borrower,
            principal: amount,
            createdAt: block.timestamp,
            drawnAt: 0,
            dueAt: 0,
            rateBps: rateBps,
            tenorDays: tenorDays,
            status: Types.LoanStatus.Requested
        });
        
        emit LoanCreated(loanId, borrower, amount, rateBps, tenorDays);
    }
    
    /**
     * @dev Approve a loan request
     * @param loanId ID of the loan to approve
     */
    function approve(uint256 loanId) external onlyRole(POOL_ROLE) {
        Types.Loan storage loan = loans[loanId];
        if (loan.borrower == address(0)) revert InvalidLoanId();
        if (loan.status != Types.LoanStatus.Requested) revert InvalidState();
        
        loan.status = Types.LoanStatus.Approved;
        
        emit LoanStatusChanged(loanId, Types.LoanStatus.Requested, Types.LoanStatus.Approved);
    }
    
    /**
     * @dev Process loan drawdown
     * @param loanId ID of the loan to drawdown
     */
    function drawdown(uint256 loanId) external onlyRole(POOL_ROLE) {
        Types.Loan storage loan = loans[loanId];
        if (loan.borrower == address(0)) revert InvalidLoanId();
        if (loan.status != Types.LoanStatus.Approved) revert InvalidState();
        
        loan.status = Types.LoanStatus.Drawn;
        loan.drawnAt = block.timestamp;
        loan.dueAt = block.timestamp + (loan.tenorDays * 1 days);
        
        emit LoanStatusChanged(loanId, Types.LoanStatus.Approved, Types.LoanStatus.Drawn);
    }
    
    /**
     * @dev Calculate current debt for a loan
     * @param loanId ID of the loan
     * @return principal Remaining principal
     * @return interest Accrued interest
     * @return lateFees Late fees (always 0 in MVP)
     * @return total Total debt
     */
    function currentDebt(uint256 loanId) external view returns (
        uint256 principal,
        uint256 interest,
        uint256 lateFees,
        uint256 total
    ) {
        Types.Loan storage loan = loans[loanId];
        if (loan.borrower == address(0)) revert InvalidLoanId();
        if (loan.status != Types.LoanStatus.Drawn) revert InvalidState();
        
        principal = loan.principal;
        interest = _calculateInterest(loan);
        lateFees = 0; // MVP: no late fees
        total = principal + interest;
    }
    
    /**
     * @dev Process loan repayment
     * @param loanId ID of the loan to repay
     * @param amount Amount being repaid
     * @return remaining Remaining debt after repayment
     */
    function repay(uint256 loanId, uint256 amount) external onlyRole(POOL_ROLE) returns (uint256 remaining) {
        if (amount == 0) revert AmountZero();
        
        Types.Loan storage loan = loans[loanId];
        if (loan.borrower == address(0)) revert InvalidLoanId();
        if (loan.status != Types.LoanStatus.Drawn) revert InvalidState();
        
        uint256 currentInterest = _calculateInterest(loan);
        uint256 totalDebt = loan.principal + currentInterest;
        
        uint256 interestPaid;
        uint256 principalPaid;
        
        if (amount >= totalDebt) {
            // Full repayment
            loan.status = Types.LoanStatus.Repaid;
            loan.principal = 0;
            remaining = 0;
            interestPaid = currentInterest;
            principalPaid = loan.principal;
            
            emit LoanStatusChanged(loanId, Types.LoanStatus.Drawn, Types.LoanStatus.Repaid);
        } else {
            // Partial repayment - prioritize interest
            interestPaid = amount <= currentInterest ? amount : currentInterest;
            principalPaid = amount - interestPaid;
            
            loan.principal -= principalPaid;
            remaining = totalDebt - amount;
        }
        
        emit LoanAccountingUpdated(loanId, interestPaid, principalPaid, remaining);
    }
    
    /**
     * @dev Mark a loan as defaulted
     * @param loanId ID of the loan to mark as defaulted
     */
    function markDefault(uint256 loanId) external onlyRole(POOL_ROLE) {
        Types.Loan storage loan = loans[loanId];
        if (loan.borrower == address(0)) revert InvalidLoanId();
        if (loan.status != Types.LoanStatus.Drawn) revert InvalidState();
        if (block.timestamp <= loan.dueAt) revert InvalidState();
        
        loan.status = Types.LoanStatus.Defaulted;
        
        emit LoanStatusChanged(loanId, Types.LoanStatus.Drawn, Types.LoanStatus.Defaulted);
    }
    
    /**
     * @dev Calculate accrued interest for a loan
     * @param loan Loan struct
     * @return Accrued interest amount
     */
    function _calculateInterest(Types.Loan storage loan) private view returns (uint256) {
        if (loan.drawnAt == 0) return 0;
        
        uint256 elapsedDays = (block.timestamp - loan.drawnAt) / 1 days;
        return (loan.principal * loan.rateBps * elapsedDays) / (10000 * 365);
    }
    
    /**
     * @dev Grant POOL_ROLE to a pool contract
     * @param pool Address of the pool contract
     */
    function grantPoolRole(address pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(POOL_ROLE, pool);
    }
    
    /**
     * @dev Revoke POOL_ROLE from a pool contract
     * @param pool Address of the pool contract
     */
    function revokePoolRole(address pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(POOL_ROLE, pool);
    }
    
    /**
     * @dev Get loan details
     * @param loanId ID of the loan
     * @return Loan struct
     */
    function getLoan(uint256 loanId) external view returns (Types.Loan memory) {
        return loans[loanId];
    }
    
    /**
     * @dev Get total loan count
     * @return Total number of loans created
     */
    function getLoanCount() external view returns (uint256) {
        return _loanCounter;
    }
}
