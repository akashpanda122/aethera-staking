// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StakingHelpers
 * @dev Helper functions and utilities for Hedera staking contract
 * Converted from Solana Anchor helper functions
 */
library StakingHelpers {
    
    // ============================================
    // CONSTANTS
    // ============================================
    
    /**
     * @dev Float scalar for high-precision calculations
     * Equivalent to Solana's 2^48 for fixed-point arithmetic
     * In Solidity, we use 10^18 (1 ether) for better decimal precision
     */
    uint256 internal constant FLOAT_SCALAR = 1e18; // 10^18 for 18 decimal places
    
    /**
     * @dev Alternative high-precision scalar (2^48 equivalent)
     * Can be used for calculations requiring exact 2^48 precision
     */
    uint256 internal constant FLOAT_SCALAR_2_48 = 281474976710656; // 2^48
    
    // Basis points for percentage calculations
    uint256 internal constant BASIS_POINTS = 10000; // 100% = 10000 basis points
    
    // Time constants
    uint256 internal constant SECONDS_PER_YEAR = 365 days;
    uint256 internal constant SECONDS_PER_DAY = 1 days;
    
    // ============================================
    // CUSTOM ERRORS
    // ============================================
    
    error TransferFailed();
    error InsufficientBalance();
    error InvalidAddress();
    error InvalidAmount();
    error ArithmeticError();
    
    // ============================================
    // TRANSFER FUNCTIONS
    // ============================================
    
    /**
     * @dev Transfer HBAR between accounts
     * Equivalent to Solana's transfer_lamports via CPI
     * @param from Address to transfer from (must be msg.sender or contract)
     * @param to Address to transfer to
     * @param amount Amount in tinybars to transfer
     */
    function transferHbar(
        address from,
        address payable to,
        uint256 amount
    ) internal {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        
        // Ensure sender has sufficient balance
        if (from == address(this)) {
            require(address(this).balance >= amount, "Insufficient contract balance");
        } else {
            require(from == msg.sender, "Unauthorized transfer");
        }
        
        // Perform transfer
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
    
    /**
     * @dev Safe transfer from contract balance
     * Equivalent to Solana's transfer_lamports_from_owned_pda
     * @param to Recipient address
     * @param amount Amount in tinybars
     */
    function transferFromContract(
        address payable to,
        uint256 amount
    ) internal {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(address(this).balance >= amount, "Insufficient balance");
        
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
    
    /**
     * @dev Safe transfer with return value check
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return success Whether transfer succeeded
     */
    function safeTransfer(
        address payable to,
        uint256 amount
    ) internal returns (bool success) {
        if (to == address(0) || amount == 0) return false;
        if (address(this).balance < amount) return false;
        
        (success, ) = to.call{value: amount}("");
    }
    
    // ============================================
    // ADDRESS COMPARISON
    // ============================================
    
    /**
     * @dev Compare two addresses for equality
     * Equivalent to Solana's cmp_pubkeys
     * @param a First address
     * @param b Second address
     * @return bool True if addresses are equal
     */
    function compareAddresses(address a, address b) internal pure returns (bool) {
        return a == b;
    }
    
    /**
     * @dev Check if address is valid (not zero)
     * @param addr Address to check
     * @return bool True if valid
     */
    function isValidAddress(address addr) internal pure returns (bool) {
        return addr != address(0);
    }
    
    // ============================================
    // MATHEMATICAL HELPERS
    // ============================================
    
    /**
     * @dev Calculate rewards with high precision
     * Uses FLOAT_SCALAR for accurate decimal calculations
     * @param principal Staked amount
     * @param apyRate APY in basis points
     * @param timeStaked Time staked in seconds
     * @return rewards Calculated rewards
     */
    function calculateRewards(
        uint256 principal,
        uint256 apyRate,
        uint256 timeStaked
    ) internal pure returns (uint256 rewards) {
        // Formula: (principal * apyRate * timeStaked) / (SECONDS_PER_YEAR * BASIS_POINTS)
        rewards = (principal * apyRate * timeStaked) / (SECONDS_PER_YEAR * BASIS_POINTS);
    }
    
    /**
     * @dev Calculate rewards with high precision using FLOAT_SCALAR
     * @param principal Staked amount
     * @param apyRate APY in basis points
     * @param timeStaked Time staked in seconds
     * @return rewards Calculated rewards
     */
    function calculateRewardsHighPrecision(
        uint256 principal,
        uint256 apyRate,
        uint256 timeStaked
    ) internal pure returns (uint256 rewards) {
        // Scale up for precision
        uint256 scaledPrincipal = principal * FLOAT_SCALAR;
        uint256 scaledRewards = (scaledPrincipal * apyRate * timeStaked) / (SECONDS_PER_YEAR * BASIS_POINTS);
        
        // Scale back down
        rewards = scaledRewards / FLOAT_SCALAR;
    }
    
    /**
     * @dev Calculate percentage of a value
     * @param value Base value
     * @param percentage Percentage in basis points (e.g., 5000 = 50%)
     * @return result Calculated percentage
     */
    function calculatePercentage(
        uint256 value,
        uint256 percentage
    ) internal pure returns (uint256 result) {
        result = (value * percentage) / BASIS_POINTS;
    }
    
    /**
     * @dev Safe multiplication with overflow check
     * @param a First number
     * @param b Second number
     * @return result Product
     */
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256 result) {
        if (a == 0) return 0;
        result = a * b;
        require(result / a == b, "Multiplication overflow");
    }
    
    /**
     * @dev Safe division with zero check
     * @param a Numerator
     * @param b Denominator
     * @return result Quotient
     */
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256 result) {
        require(b > 0, "Division by zero");
        result = a / b;
    }
    
    // ============================================
    // TIME HELPERS
    // ============================================
    
    /**
     * @dev Get current timestamp
     * @return uint256 Current block timestamp
     */
    function getCurrentTime() internal view returns (uint256) {
        return block.timestamp;
    }
    
    /**
     * @dev Calculate time elapsed
     * @param startTime Start timestamp
     * @return elapsed Time elapsed in seconds
     */
    function getTimeElapsed(uint256 startTime) internal view returns (uint256 elapsed) {
        require(startTime <= block.timestamp, "Invalid start time");
        elapsed = block.timestamp - startTime;
    }
    
    /**
     * @dev Check if duration has passed
     * @param startTime Start timestamp
     * @param duration Duration in seconds
     * @return bool True if duration has passed
     */
    function hasDurationPassed(
        uint256 startTime,
        uint256 duration
    ) internal view returns (bool) {
        return block.timestamp >= startTime + duration;
    }
    
    /**
     * @dev Get remaining time in duration
     * @param startTime Start timestamp
     * @param duration Total duration
     * @return remaining Remaining time (0 if expired)
     */
    function getRemainingTime(
        uint256 startTime,
        uint256 duration
    ) internal view returns (uint256 remaining) {
        uint256 endTime = startTime + duration;
        if (block.timestamp >= endTime) {
            return 0;
        }
        remaining = endTime - block.timestamp;
    }
    
    // ============================================
    // CONVERSION HELPERS
    // ============================================
    
    /**
     * @dev Convert HBAR to tinybars
     * @param hbar Amount in HBAR
     * @return tinybars Amount in tinybars (1 HBAR = 10^8 tinybars)
     */
    function hbarToTinybars(uint256 hbar) internal pure returns (uint256 tinybars) {
        tinybars = hbar * 1e8;
    }
    
    /**
     * @dev Convert tinybars to HBAR
     * @param tinybars Amount in tinybars
     * @return hbar Amount in HBAR
     */
    function tinybarsToHbar(uint256 tinybars) internal pure returns (uint256 hbar) {
        hbar = tinybars / 1e8;
    }
    
    /**
     * @dev Convert basis points to percentage (for display)
     * @param basisPoints APY in basis points
     * @return percentage Percentage with 2 decimals (e.g., 5000 = 50.00%)
     */
    function basisPointsToPercentage(uint256 basisPoints) internal pure returns (uint256 percentage) {
        percentage = basisPoints / 100; // 5000 basis points = 50%
    }
    
    // ============================================
    // VALIDATION HELPERS
    // ============================================
    
    /**
     * @dev Validate stake amount
     * @param amount Amount to validate
     * @param minAmount Minimum allowed amount
     * @param maxAmount Maximum allowed amount
     * @return bool True if valid
     */
    function isValidStakeAmount(
        uint256 amount,
        uint256 minAmount,
        uint256 maxAmount
    ) internal pure returns (bool) {
        return amount >= minAmount && amount <= maxAmount;
    }
    
    /**
     * @dev Validate duration
     * @param duration Duration to validate
     * @param minDuration Minimum allowed duration
     * @param maxDuration Maximum allowed duration
     * @return bool True if valid
     */
    function isValidDuration(
        uint256 duration,
        uint256 minDuration,
        uint256 maxDuration
    ) internal pure returns (bool) {
        return duration >= minDuration && duration <= maxDuration;
    }
    
    /**
     * @dev Check if contract has sufficient balance
     * @param required Required amount
     * @return bool True if sufficient
     */
    function hasSufficientBalance(uint256 required) internal view returns (bool) {
        return address(this).balance >= required;
    }
    
    // ============================================
    // HASH HELPERS (for future use)
    // ============================================
    
    /**
     * @dev Generate keccak256 hash
     * Equivalent to Solana's keccak hash
     * @param data Data to hash
     * @return hash Hash result
     */
    function generateHash(bytes memory data) internal pure returns (bytes32 hash) {
        hash = keccak256(data);
    }
    
    /**
     * @dev Generate hash from address and timestamp
     * Useful for unique identifiers
     * @param addr Address
     * @param timestamp Timestamp
     * @return hash Hash result
     */
    function generateUniqueHash(
        address addr,
        uint256 timestamp
    ) internal pure returns (bytes32 hash) {
        hash = keccak256(abi.encodePacked(addr, timestamp));
    }
}

/**
 * @title StakingErrors
 * @dev Custom error definitions for the staking contract
 * Equivalent to Solana's StakingError enum
 */
library StakingErrors {
    // Error codes
    error InsufficientBalance(uint256 required, uint256 available);
    error InvalidStakeAmount(uint256 amount, uint256 min, uint256 max);
    error InvalidDuration(uint256 duration, uint256 min, uint256 max);
    error InvalidApyRate(uint256 rate, uint256 min, uint256 max);
    error StakeNotFound(address player);
    error StakeLocked(uint256 unlockTime);
    error NoRewardsToClaim();
    error Unauthorized(address caller, address expected);
    error AlreadyInitialized();
    error NotInitialized();
    error TransferFailed();
    error ContractPaused();
    error InvalidAddress(address addr);
}

/**
 * @title ReentrancyGuard
 * @dev Protection against reentrancy attacks
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    
    uint256 private _status;
    
    constructor() {
        _status = _NOT_ENTERED;
    }
    
    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrancy detected");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}