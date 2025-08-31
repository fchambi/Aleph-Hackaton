// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./MicroCreditPool.sol";
import "./libs/Types.sol";

/**
 * @title MicroCreditPoolFactory
 * @dev Factory contract for creating MicroCredit pools
 */
contract MicroCreditPoolFactory is AccessControl {
    // Array of all created pools
    address[] public pools;
    
    // Mapping from pool address to creation info
    mapping(address => bool) public isPool;
    
    // Events
    event PoolCreated(
        address indexed pool,
        address indexed stable,
        Types.PoolParams params
    );
    
    // Custom errors
    error InvalidAddress();
    error PoolAlreadyExists();
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev Create a new MicroCredit pool
     * @param stable Address of the stablecoin (e.g., USDC)
     * @param params Pool configuration parameters
     * @param name Name for the LP token
     * @param symbol Symbol for the LP token
     * @return pool Address of the created pool
     */
    function createPool(
        address stable,
        Types.PoolParams calldata params,
        string memory name,
        string memory symbol
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (address pool) {
        if (stable == address(0)) revert InvalidAddress();
        if (bytes(name).length == 0 || bytes(symbol).length == 0) revert InvalidAddress();
        
        // Validate pool parameters
        if (params.interestRateBps > 10000) revert InvalidAddress(); // Max 100% APR
        if (params.tenorDays == 0 || params.tenorDays > 3650) revert InvalidAddress(); // Max 10 years
        if (params.maxLoanToPoolBps > 10000) revert InvalidAddress(); // Max 100% of pool
        if (params.reserveFactorBps > 10000) revert InvalidAddress(); // Max 100% of interest
        if (params.minCreditScore > 100) revert InvalidAddress(); // Max score 100
        
        // Create pool contract
        pool = address(new MicroCreditPool(
            stable,
            address(this), // Factory will be the loan manager initially
            address(this), // Factory will be the credit score registry initially
            address(this), // Factory will be the treasury initially
            params,
            name,
            symbol
        ));
        
        // Register pool
        pools.push(pool);
        isPool[pool] = true;
        
        emit PoolCreated(pool, stable, params);
    }
    
    /**
     * @dev Get all created pools
     * @return Array of pool addresses
     */
    function getPools() external view returns (address[] memory) {
        return pools;
    }
    
    /**
     * @dev Get pool count
     * @return Total number of pools created
     */
    function getPoolCount() external view returns (uint256) {
        return pools.length;
    }
    
    /**
     * @dev Check if an address is a valid pool
     * @param pool Address to check
     * @return True if the address is a valid pool
     */
    function isValidPool(address pool) external view returns (bool) {
        return isPool[pool];
    }
    
    /**
     * @dev Grant DEFAULT_ADMIN_ROLE to an address
     * @param admin Address to grant the role to
     */
    function grantAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (admin == address(0)) revert InvalidAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }
    
    /**
     * @dev Revoke DEFAULT_ADMIN_ROLE from an address
     * @param admin Address to revoke the role from
     */
    function revokeAdminRole(address admin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (admin == msg.sender) revert InvalidAddress(); // Cannot revoke own role
        _revokeRole(DEFAULT_ADMIN_ROLE, admin);
    }
    
    /**
     * @dev Pause all pools (emergency function)
     * @param poolAddresses Array of pool addresses to pause
     */
    function pausePools(address[] calldata poolAddresses) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < poolAddresses.length; i++) {
            address pool = poolAddresses[i];
            if (isPool[pool]) {
                MicroCreditPool(pool).pause();
            }
        }
    }
    
    /**
     * @dev Unpause all pools
     * @param poolAddresses Array of pool addresses to unpause
     */
    function unpausePools(address[] calldata poolAddresses) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < poolAddresses.length; i++) {
            address pool = poolAddresses[i];
            if (isPool[pool]) {
                MicroCreditPool(pool).unpause();
            }
        }
    }
}
