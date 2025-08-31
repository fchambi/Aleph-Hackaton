// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title CreditScoreRegistry
 * @dev Manages credit scores for users in the MicroCredit DAO
 */
contract CreditScoreRegistry is AccessControl {
    bytes32 public constant POOL_ROLE = keccak256("POOL_ROLE");
    
    // Mapping from user address to credit score (0-100)
    mapping(address => uint256) public score;
    
    // Events
    event ScoreUpdated(address indexed user, uint256 oldScore, uint256 newScore);
    
    // Custom errors
    error ScoreOutOfRange();
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Get the credit score for a user
     * @param user Address of the user
     * @return Current credit score (0-100)
     */
    function getScore(address user) external view returns (uint256) {
        return score[user];
    }
    
    /**
     * @dev Increase the credit score for a user
     * @param user Address of the user
     * @param delta Amount to increase the score by
     */
    function increaseScore(address user, uint256 delta) external onlyRole(POOL_ROLE) {
        uint256 oldScore = score[user];
        uint256 newScore = oldScore + delta;
        
        // Clamp to maximum of 100
        if (newScore > 100) {
            newScore = 100;
        }
        
        score[user] = newScore;
        emit ScoreUpdated(user, oldScore, newScore);
    }
    
    /**
     * @dev Decrease the credit score for a user
     * @param user Address of the user
     * @param delta Amount to decrease the score by
     */
    function decreaseScore(address user, uint256 delta) external onlyRole(POOL_ROLE) {
        uint256 oldScore = score[user];
        uint256 newScore;
        
        if (delta >= oldScore) {
            newScore = 0;
        } else {
            newScore = oldScore - delta;
        }
        
        score[user] = newScore;
        emit ScoreUpdated(user, oldScore, newScore);
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
}
