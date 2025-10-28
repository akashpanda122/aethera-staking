// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StakingErrors
 * @dev Custom error definitions for Hedera staking contract
 * Converted from Solana Anchor error codes
 * 
 * Benefits of custom errors:
 * - Gas efficient (cheaper than require with string)
 * - Can include parameters for debugging
 * - Better error handling in frontends
 */

/**
 * @dev Thrown when an invalid argument is provided
 * @param parameter Name or identifier of the invalid parameter
 */
error InvalidArgument(string parameter);

/**
 * @dev Thrown when a numerical operation would overflow
 * @param operation Description of the operation that failed
 * @param value The value that caused overflow
 */
error NumericalOverflow(string operation, uint256 value);

/**
 * @dev Thrown when an invalid token contract is provided
 * In Hedera context: invalid HTS token or fungible token address
 * @param tokenAddress The invalid token address
 */
error InvalidTokenAddress(address tokenAddress);

/**
 * @dev Thrown when an account has insufficient balance
 * @param required Amount required for the operation
 * @param available Amount currently available
 */
error InsufficientBalance(uint256 required, uint256 available);

/**
 * @dev Thrown when unstaking with insufficient staked amount
 * @param requested Amount requested to unstake
 * @param staked Amount currently staked
 */
error InsufficientStake(uint256 requested, uint256 staked);

/**
 * @dev Thrown when a delegatecall or external call is not allowed
 * In Solidity context: prevents malicious reentrancy or unauthorized calls
 * @param caller Address that attempted the unauthorized call
 */
error UnauthorizedCall(address caller);

/**
 * @dev Thrown when an unauthorized contract attempts interaction
 * @param program Address of the unauthorized program/contract
 */
error UnauthorizedProgram(address program);

/**
 * @dev Thrown when rate limit is exceeded
 * @param caller Address that exceeded the rate limit
 * @param waitTime Time in seconds before next allowed action
 */
error RateLimitExceeded(address caller, uint256 waitTime);

/**
 * @dev Thrown when trying to unstake before lock period ends
 * @param currentTime Current block timestamp
 * @param unlockTime Time when unstaking becomes available
 * @param remainingTime Seconds remaining until unlock
 */
error InvalidUnstakeTime(uint256 currentTime, uint256 unlockTime, uint256 remainingTime);

/**
 * @dev Thrown when trying to claim rewards at an invalid time
 * @param lastClaimTime Last time rewards were claimed
 * @param nextClaimTime Earliest time next claim is allowed
 */
error InvalidRewardTime(uint256 lastClaimTime, uint256 nextClaimTime);

/**
 * @dev Thrown when an amount of zero or less is provided
 * @param operation The operation that requires a positive amount
 */
error AmountMustBeGreaterThanZero(string operation);

/**
 * @title ExtendedStakingErrors
 * @dev Additional error definitions specific to Hedera staking
 */

/**
 * @dev Contract is not initialized
 */
error NotInitialized();

/**
 * @dev Contract is already initialized
 */
error AlreadyInitialized();

/**
 * @dev Only authority/admin can perform this action
 * @param caller Address that attempted the action
 * @param authority Expected authority address
 */
error OnlyAuthority(address caller, address authority);

/**
 * @dev Contract is paused
 */
error ContractPaused();

/**
 * @dev Contract is not paused
 */
error ContractNotPaused();

/**
 * @dev Invalid duration provided
 * @param duration Provided duration
 * @param minDuration Minimum allowed duration
 * @param maxDuration Maximum allowed duration
 */
error InvalidDuration(uint256 duration, uint256 minDuration, uint256 maxDuration);

/**
 * @dev Invalid APY rate
 * @param rate Provided rate
 * @param minRate Minimum allowed rate
 * @param maxRate Maximum allowed rate
 */
error InvalidApyRate(uint256 rate, uint256 minRate, uint256 maxRate);

/**
 * @dev No stake found for the address
 * @param player Address with no stake
 */
error NoStakeFound(address player);

/**
 * @dev No rewards available to claim
 * @param player Address with no rewards
 */
error NoRewardsToClaim(address player);

/**
 * @dev Transfer failed
 * @param to Recipient address
 * @param amount Amount that failed to transfer
 */
error TransferFailed(address to, uint256 amount);

/**
 * @dev Invalid address provided (zero address)
 * @param parameter Parameter name that had invalid address
 */
error InvalidAddress(string parameter);

/**
 * @dev Stake is still locked
 * @param unlockTime Time when stake will unlock
 */
error StakeLocked(uint256 unlockTime);

/**
 * @dev Insufficient contract balance for operation
 * @param required Amount required
 * @param available Contract balance available
 */
error InsufficientContractBalance(uint256 required, uint256 available);

/**
 * @dev Maximum stake limit exceeded
 * @param requested Requested stake amount
 * @param maximum Maximum allowed stake
 */
error MaxStakeExceeded(uint256 requested, uint256 maximum);

/**
 * @dev Minimum stake requirement not met
 * @param provided Provided stake amount
 * @param minimum Minimum required stake
 */
error MinStakeNotMet(uint256 provided, uint256 minimum);

/**
 * @dev Reentrancy detected
 */
error ReentrancyDetected();

/**
 * @dev Invalid configuration parameter
 * @param parameter Parameter that is invalid
 * @param value Value provided
 */
error InvalidConfiguration(string parameter, uint256 value);

/**
 * @title StakingErrorHandler
 * @dev Helper contract for consistent error handling
 */
abstract contract StakingErrorHandler {
    
    /**
     * @dev Validate stake amount
     * @param amount Amount to validate
     * @param minAmount Minimum allowed
     * @param maxAmount Maximum allowed
     */
    function _validateStakeAmount(
        uint256 amount,
        uint256 minAmount,
        uint256 maxAmount
    ) internal pure {
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero("stake");
        }
        if (amount < minAmount) {
            revert MinStakeNotMet(amount, minAmount);
        }
        if (amount > maxAmount) {
            revert MaxStakeExceeded(amount, maxAmount);
        }
    }
    
    /**
     * @dev Validate duration
     * @param duration Duration to validate
     * @param minDuration Minimum allowed
     * @param maxDuration Maximum allowed
     */
    function _validateDuration(
        uint256 duration,
        uint256 minDuration,
        uint256 maxDuration
    ) internal pure {
        if (duration == 0) {
            revert InvalidArgument("duration");
        }
        if (duration < minDuration || duration > maxDuration) {
            revert InvalidDuration(duration, minDuration, maxDuration);
        }
    }
    
    /**
     * @dev Validate address is not zero
     * @param addr Address to validate
     * @param parameter Parameter name for error message
     */
    function _validateAddress(address addr, string memory parameter) internal pure {
        if (addr == address(0)) {
            revert InvalidAddress(parameter);
        }
    }
    
    /**
     * @dev Check if balance is sufficient
     * @param available Available balance
     * @param required Required balance
     */
    function _checkSufficientBalance(
        uint256 available,
        uint256 required
    ) internal pure {
        if (available < required) {
            revert InsufficientBalance(required, available);
        }
    }
    
    /**
     * @dev Check if contract has sufficient balance
     * @param required Required amount
     */
    function _checkContractBalance(uint256 required) internal view {
        uint256 available = address(this).balance;
        if (available < required) {
            revert InsufficientContractBalance(required, available);
        }
    }
    
    /**
     * @dev Validate APY rate
     * @param rate Rate to validate
     * @param minRate Minimum allowed rate
     * @param maxRate Maximum allowed rate
     */
    function _validateApyRate(
        uint256 rate,
        uint256 minRate,
        uint256 maxRate
    ) internal pure {
        if (rate < minRate || rate > maxRate) {
            revert InvalidApyRate(rate, minRate, maxRate);
        }
    }
    
    /**
     * @dev Check if stake is unlocked
     * @param stakedTime Time when stake was made
     * @param duration Lock duration
     */
    function _checkStakeUnlocked(
        uint256 stakedTime,
        uint256 duration
    ) internal view {
        uint256 unlockTime = stakedTime + duration;
        if (block.timestamp < unlockTime) {
            uint256 remainingTime = unlockTime - block.timestamp;
            revert InvalidUnstakeTime(block.timestamp, unlockTime, remainingTime);
        }
    }
    
    /**
     * @dev Safe transfer with error handling
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function _safeTransfer(address payable to, uint256 amount) internal {
        _validateAddress(to, "recipient");
        _checkContractBalance(amount);
        
        (bool success, ) = to.call{value: amount}("");
        if (!success) {
            revert TransferFailed(to, amount);
        }
    }
}

/**
 * @title ErrorCodes
 * @dev Optional: Error codes as constants for off-chain error handling
 */
library ErrorCodes {
    uint256 constant INVALID_ARGUMENT = 1;
    uint256 constant NUMERICAL_OVERFLOW = 2;
    uint256 constant INVALID_TOKEN_ADDRESS = 3;
    uint256 constant INSUFFICIENT_BALANCE = 4;
    uint256 constant INSUFFICIENT_STAKE = 5;
    uint256 constant UNAUTHORIZED_CALL = 6;
    uint256 constant UNAUTHORIZED_PROGRAM = 7;
    uint256 constant RATE_LIMIT_EXCEEDED = 8;
    uint256 constant INVALID_UNSTAKE_TIME = 9;
    uint256 constant INVALID_REWARD_TIME = 10;
    uint256 constant AMOUNT_MUST_BE_GREATER_THAN_ZERO = 11;
    uint256 constant NOT_INITIALIZED = 12;
    uint256 constant ALREADY_INITIALIZED = 13;
    uint256 constant ONLY_AUTHORITY = 14;
    uint256 constant CONTRACT_PAUSED = 15;
    uint256 constant INVALID_DURATION = 16;
    uint256 constant INVALID_APY_RATE = 17;
    uint256 constant NO_STAKE_FOUND = 18;
    uint256 constant NO_REWARDS_TO_CLAIM = 19;
    uint256 constant TRANSFER_FAILED = 20;
    uint256 constant STAKE_LOCKED = 21;
}