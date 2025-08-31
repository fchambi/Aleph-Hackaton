// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libs/Types.sol";
import "./interfaces/IPool.sol";
import "./interfaces/ILoanManager.sol";
import "./interfaces/ICreditScoreRegistry.sol";
import "./interfaces/ITreasury.sol";

/**
 * @title MicroCreditPool
 * @dev Main pool contract for MicroCredit DAO that manages deposits, loans, and LP shares
 */
contract MicroCreditPool is IPool, ERC20, ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    // Immutable addresses
    IERC20 public immutable stable;
    ILoanManager public immutable loanManager;
    ICreditScoreRegistry public immutable creditScoreRegistry;
    ITreasury public immutable treasury;
    
    // Pool parameters
    Types.PoolParams public params;
    
    // Pool state
    uint256 public totalAssets;
    
    // Events
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 shares, uint256 amount);
    event LoanRequested(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanApproved(uint256 indexed loanId);
    event LoanDrawn(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, address indexed payer, uint256 paidAmount);
    event LoanDefaulted(uint256 indexed loanId);
    event ParamsUpdated(Types.PoolParams oldParams, Types.PoolParams newParams);
    
    // Custom errors
    error AmountZero();
    error LowScore();
    error ExceedsPoolRatio();
    error InvalidState();
    error NotManager();
    error NothingToWithdraw();
    error InsufficientBalance();
    
    /**
     * @dev Constructor
     * @param _stable Address of the stablecoin (e.g., USDC)
     * @param _loanManager Address of the loan manager
     * @param _creditScoreRegistry Address of the credit score registry
     * @param _treasury Address of the treasury
     * @param _params Pool parameters
     * @param _name Name for LP token
     * @param _symbol Symbol for LP token
     */
    constructor(
        address _stable,
        address _loanManager,
        address _creditScoreRegistry,
        address _treasury,
        Types.PoolParams memory _params,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        stable = IERC20(_stable);
        loanManager = ILoanManager(_loanManager);
        creditScoreRegistry = ICreditScoreRegistry(_creditScoreRegistry);
        treasury = ITreasury(_treasury);
        params = _params;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Deposit stablecoins and receive LP shares
     * @param amount Amount of stablecoins to deposit
     */
    function deposit(uint256 amount) external override nonReentrant whenNotPaused {
        if (amount == 0) revert AmountZero();
        
        uint256 shares;
        if (totalSupply() == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupply()) / totalAssets;
        }
        
        if (shares == 0) revert AmountZero();
        
        // Transfer stablecoins from user to pool
        stable.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update state
        totalAssets += amount;
        
        // Mint LP shares
        _mint(msg.sender, shares);
        
        emit Deposited(msg.sender, amount, shares);
    }
    
    /**
     * @dev Withdraw stablecoins by burning LP shares
     * @param shares Amount of LP shares to burn
     */
    function withdraw(uint256 shares) external override nonReentrant whenNotPaused {
        if (shares == 0) revert AmountZero();
        if (balanceOf(msg.sender) < shares) revert InsufficientBalance();
        
        uint256 amount = (shares * totalAssets) / totalSupply();
        if (amount == 0) revert NothingToWithdraw();
        
        // Burn LP shares
        _burn(msg.sender, shares);
        
        // Update state
        totalAssets -= amount;
        
        // Transfer stablecoins to user
        stable.safeTransfer(msg.sender, amount);
        
        emit Withdrawn(msg.sender, shares, amount);
    }
    
    /**
     * @dev Request a loan from the pool
     * @param amount Amount of stablecoins requested
     * @return loanId ID of the created loan
     */
    function requestLoan(uint256 amount) external override whenNotPaused returns (uint256 loanId) {
        if (amount == 0) revert AmountZero();
        if (amount > totalAssets * params.maxLoanToPoolBps / 10000) revert ExceedsPoolRatio();
        
        // Check credit score if required
        if (params.minCreditScore > 0) {
            uint256 userScore = creditScoreRegistry.getScore(msg.sender);
            if (userScore < params.minCreditScore) revert LowScore();
        }
        
        // Create loan in loan manager
        loanId = loanManager.createLoan(msg.sender, amount, params.interestRateBps, params.tenorDays);
        
        emit LoanRequested(loanId, msg.sender, amount);
    }
    
    /**
     * @dev Approve a loan request (manager only)
     * @param loanId ID of the loan to approve
     */
    function approveLoan(uint256 loanId) external override onlyRole(MANAGER_ROLE) whenNotPaused {
        loanManager.approve(loanId);
        emit LoanApproved(loanId);
    }
    
    /**
     * @dev Process loan drawdown (borrower only)
     * @param loanId ID of the loan to drawdown
     */
    function drawdown(uint256 loanId) external override nonReentrant whenNotPaused {
        // Get loan details to verify borrower
        Types.Loan memory loan = loanManager.getLoan(loanId);
        if (loan.borrower != msg.sender) revert InvalidState();
        
        // Process drawdown in loan manager
        loanManager.drawdown(loanId);
        
        // Transfer stablecoins to borrower
        stable.safeTransfer(msg.sender, loan.principal);
        
        // Update pool state
        totalAssets -= loan.principal;
        
        emit LoanDrawn(loanId, msg.sender, loan.principal);
    }
    
    /**
     * @dev Repay a loan
     * @param loanId ID of the loan to repay
     * @param amount Amount of stablecoins to repay
     * @return remaining Remaining debt after repayment
     */
    function repay(uint256 loanId, uint256 amount) external override nonReentrant whenNotPaused returns (uint256 remaining) {
        if (amount == 0) revert AmountZero();
        
        // Transfer stablecoins from user to pool
        stable.safeTransferFrom(msg.sender, address(this), amount);
        
        // Get debt breakdown before repayment
        (uint256 principalBefore, uint256 interestBefore, , ) = loanManager.currentDebt(loanId);
        
        // Process repayment in loan manager
        remaining = loanManager.repay(loanId, amount);
        
        // Get debt breakdown after repayment
        (uint256 principalAfter, uint256 interestAfter, , ) = loanManager.currentDebt(loanId);
        
        // Calculate amounts paid
        uint256 principalPaid = principalBefore - principalAfter;
        uint256 interestPaid = interestBefore - interestAfter;
        
        // Calculate treasury fee
        uint256 feeInterest = (interestPaid * params.reserveFactorBps) / 10000;
        
        // Send fee to treasury
        if (feeInterest > 0) {
            stable.safeApprove(address(treasury), feeInterest);
            treasury.receiveFees(address(stable), feeInterest);
        }
        
        // Update pool state with net amounts
        uint256 netInterest = interestPaid - feeInterest;
        totalAssets += principalPaid + netInterest;
        
        // Check if loan is fully repaid
        if (remaining == 0) {
            // Increase borrower's credit score
            creditScoreRegistry.increaseScore(msg.sender, 15);
            emit LoanRepaid(loanId, msg.sender, amount);
        }
    }
    
    /**
     * @dev Mark a loan as defaulted (manager only)
     * @param loanId ID of the loan to mark as defaulted
     */
    function markDefault(uint256 loanId) external override onlyRole(MANAGER_ROLE) whenNotPaused {
        // Get loan details
        Types.Loan memory loan = loanManager.getLoan(loanId);
        
        // Mark as defaulted in loan manager
        loanManager.markDefault(loanId);
        
        // Decrease borrower's credit score
        creditScoreRegistry.decreaseScore(loan.borrower, 30);
        
        emit LoanDefaulted(loanId);
    }
    
    /**
     * @dev Get current pool parameters
     * @return Pool parameters
     */
    function getParams() external view override returns (Types.PoolParams memory) {
        return params;
    }
    
    /**
     * @dev Update pool parameters (manager only)
     * @param newParams New pool parameters
     */
    function setParams(Types.PoolParams calldata newParams) external onlyRole(MANAGER_ROLE) {
        Types.PoolParams memory oldParams = params;
        params = newParams;
        
        emit ParamsUpdated(oldParams, newParams);
    }
    
    /**
     * @dev Pause the pool (manager only)
     */
    function pause() external onlyRole(MANAGER_ROLE) {
        _pause();
    }
    
    /**
     * @dev Unpause the pool (manager only)
     */
    function unpause() external onlyRole(MANAGER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Grant MANAGER_ROLE to an address
     * @param manager Address to grant the role to
     */
    function grantManagerRole(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MANAGER_ROLE, manager);
    }
    
    /**
     * @dev Revoke MANAGER_ROLE from an address
     * @param manager Address to revoke the role from
     */
    function revokeManagerRole(address manager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MANAGER_ROLE, manager);
    }
    
    /**
     * @dev Get total assets in the pool
     * @return Total assets amount
     */
    function getTotalAssets() external view returns (uint256) {
        return totalAssets;
    }
    
    /**
     * @dev Calculate shares for a given amount of stablecoins
     * @param amount Amount of stablecoins
     * @return shares Corresponding LP shares
     */
    function calculateShares(uint256 amount) external view returns (uint256 shares) {
        if (totalSupply() == 0) {
            shares = amount;
        } else {
            shares = (amount * totalSupply()) / totalAssets;
        }
    }
    
    /**
     * @dev Calculate stablecoins for a given amount of LP shares
     * @param shares Amount of LP shares
     * @return amount Corresponding stablecoins
     */
    function calculateAmount(uint256 shares) external view returns (uint256 amount) {
        if (totalSupply() == 0) {
            amount = 0;
        } else {
            amount = (shares * totalAssets) / totalSupply();
        }
    }
}
