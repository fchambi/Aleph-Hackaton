// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Treasury
 * @dev Manages fees received from MicroCredit pools
 */
contract Treasury is AccessControl {
    using SafeERC20 for IERC20;
    
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    bytes32 public constant TREASURY_ADMIN_ROLE = keccak256("TREASURY_ADMIN_ROLE");
    
    // Events
    event FeesReceived(address indexed token, uint256 amount);
    event Claimed(address indexed token, address indexed to, uint256 amount);
    
    // Custom errors
    error AmountZero();
    error InsufficientBalance();
    error TransferFailed();
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURY_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Receive fees from a pool
     * @param token Address of the token being received
     * @param amount Amount of tokens received
     */
    function receiveFees(address token, uint256 amount) external onlyRole(POOL_ROLE) {
        if (amount == 0) revert AmountZero();
        
        // Transfer tokens from the pool to this treasury
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        emit FeesReceived(token, amount);
    }
    
    /**
     * @dev Get the balance of a specific token in the treasury
     * @param token Address of the token
     * @return Balance amount
     */
    function balanceOf(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    /**
     * @dev Claim tokens from the treasury
     * @param token Address of the token to claim
     * @param to Address to send the tokens to
     * @param amount Amount of tokens to claim
     */
    function claim(address token, address to, uint256 amount) external onlyRole(TREASURY_ADMIN_ROLE) {
        if (amount == 0) revert AmountZero();
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (amount > balance) revert InsufficientBalance();
        
        IERC20(token).safeTransfer(to, amount);
        
        emit Claimed(token, to, amount);
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
     * @dev Grant TREASURY_ADMIN_ROLE to an address
     * @param admin Address to grant the role to
     */
    function grantTreasuryAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(TREASURY_ADMIN_ROLE, admin);
    }
    
    /**
     * @dev Revoke TREASURY_ADMIN_ROLE from an address
     * @param admin Address to revoke the role from
     */
    function revokeTreasuryAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(TREASURY_ADMIN_ROLE, admin);
    }
}
