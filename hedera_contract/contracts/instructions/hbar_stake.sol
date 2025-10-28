// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HederaStakingStake
 * @dev Stake functionality for Hedera staking contract
 * Converted from Solana Anchor sol_stake instruction
 */

// Required structures
struct VaultAccount {
    address authority;
    uint256 stakedAmount;
    uint256 apyRate;
}

struct PlayerAccount {
    uint256 stakedTime;
    uint256 stakedAmount;
    uint256 rewardTime;
    uint256 durationTime;
    uint256 rewardAmount;
}

// Custom errors
error AmountMustBeGreaterThanZero(string operation);
error InvalidDuration(uint256 duration, uint256 minDuration, uint256 maxDuration);
error MaxStakeExceeded(uint256 requested, uint256 maximum);
error MinStakeNotMet(uint256 provided, uint256 minimum);
error InsufficientBalance(uint256 required, uint256 available);
error TransferFailed(address to, uint256 amount);
error StakeAlreadyActive(address player);
error ContractPaused();

/**
 * @title StakingStake
 * @dev Contract module for staking functionality
 */
abstract contract StakingStake {
    
    // State variables
    VaultAccount internal vault;
    mapping(address => PlayerAccount) internal players;
    
    // Configuration
    uint256 public constant MIN_STAKE_AMOUNT = 1e8;      // 1 HBAR
    uint256 public constant MAX_STAKE_AMOUNT = 1e14;     // 1,000,000 HBAR
    uint256 public constant MIN_DURATION = 7 days;        // 7 days minimum
    uint256 public constant MAX_DURATION = 365 days;      // 365 days maximum
    
    bool public paused;
    uint256 public totalStakers;
    
    // Events
    /**
     * @dev Emitted when a player stakes
     * @param player Address that staked
     * @param amount Amount staked in tinybars
     * @param duration Lock duration in seconds
     * @param timestamp Time of stake
     */
    event SolStakeEvent(
        address indexed player,
        uint256 amount,
        uint256 duration,
        uint256 timestamp
    );
    
    /**
     * @dev Detailed stake event
     * @param player Player address
     * @param amount Amount staked
     * @param duration Lock duration
     * @param unlockTime When stake unlocks
     * @param previousStake Previous stake amount (if adding to existing)
     * @param newTotalStake New total stake for player
     */
    event StakeDetails(
        address indexed player,
        uint256 amount,
        uint256 duration,
        uint256 unlockTime,
        uint256 previousStake,
        uint256 newTotalStake
    );
    
    /**
     * @dev Emitted when vault is updated
     * @param previousTotal Previous total staked
     * @param newTotal New total staked
     * @param amountAdded Amount added
     */
    event VaultStakeUpdated(
        uint256 previousTotal,
        uint256 newTotal,
        uint256 amountAdded
    );
    
    // Modifiers
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }
    
    modifier validStakeAmount(uint256 amount) {
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero("stake");
        }
        if (amount < MIN_STAKE_AMOUNT) {
            revert MinStakeNotMet(amount, MIN_STAKE_AMOUNT);
        }
        if (amount > MAX_STAKE_AMOUNT) {
            revert MaxStakeExceeded(amount, MAX_STAKE_AMOUNT);
        }
        _;
    }
    
    modifier validDuration(uint256 duration) {
        if (duration < MIN_DURATION || duration > MAX_DURATION) {
            revert InvalidDuration(duration, MIN_DURATION, MAX_DURATION);
        }
        _;
    }
    
    /**
     * @dev Main stake function
     * Equivalent to Solana's sol_stake instruction
     * @param duration Lock duration in seconds
     * 
     * Requirements:
     * - amount must be > 0 (sent as msg.value)
     * - duration must be within allowed range
     * - contract must not be paused
     */
    function stake(uint256 duration) 
        external 
        payable 
        whenNotPaused
        validStakeAmount(msg.value)
        validDuration(duration)
    {
        // Get player address (equivalent to ctx.accounts.player.key())
        address player = msg.sender;
        uint256 amount = msg.value;
        
        // Get current time (equivalent to Clock::get().unwrap().unix_timestamp)
        uint256 currentTime = block.timestamp;
        
        // Access player data (init_if_needed equivalent)
        PlayerAccount storage playerData = players[player];
        
        // Store previous stake for event
        uint256 previousStake = playerData.stakedAmount;
        
        // If first time staking, increment total stakers
        if (previousStake == 0) {
            totalStakers++;
        } else {
            // If player has existing stake, calculate and store accumulated rewards
            uint256 accumulatedRewards = _calculateRewards(player);
            playerData.rewardAmount += accumulatedRewards;
        }
        
        // Update player data
        playerData.stakedAmount += amount;
        playerData.stakedTime = currentTime;
        playerData.durationTime = duration;
        playerData.rewardTime = currentTime;
        
        // Update vault data
        uint256 previousVaultStaked = vault.stakedAmount;
        vault.stakedAmount += amount;
        
        // Log stake amount and duration (equivalent to msg! macro)
        // In Solidity, we use events for logging
        
        // Note: In Solana, transfer happens via CPI
        // In Solidity, funds are automatically received via msg.value
        // No explicit transfer needed as HBAR is already in contract
        
        // Calculate unlock time
        uint256 unlockTime = currentTime + duration;
        
        // Emit events
        emit SolStakeEvent(
            player,
            amount,
            duration,
            currentTime
        );
        
        emit StakeDetails(
            player,
            amount,
            duration,
            unlockTime,
            previousStake,
            playerData.stakedAmount
        );
        
        emit VaultStakeUpdated(
            previousVaultStaked,
            vault.stakedAmount,
            amount
        );
    }
    
    /**
     * @dev Stake with specific amount and duration (alternative interface)
     * @param amount Amount to stake (must match msg.value)
     * @param duration Lock duration in seconds
     */
    function stakeWithAmount(uint256 amount, uint256 duration) 
        external 
        payable 
        whenNotPaused
        validStakeAmount(amount)
        validDuration(duration)
    {
        require(msg.value == amount, "Amount mismatch");
        
        address player = msg.sender;
        uint256 currentTime = block.timestamp;
        
        PlayerAccount storage playerData = players[player];
        uint256 previousStake = playerData.stakedAmount;
        
        if (previousStake == 0) {
            totalStakers++;
        } else {
            uint256 accumulatedRewards = _calculateRewards(player);
            playerData.rewardAmount += accumulatedRewards;
        }
        
        playerData.stakedAmount += amount;
        playerData.stakedTime = currentTime;
        playerData.durationTime = duration;
        playerData.rewardTime = currentTime;
        
        uint256 previousVaultStaked = vault.stakedAmount;
        vault.stakedAmount += amount;
        
        uint256 unlockTime = currentTime + duration;
        
        emit SolStakeEvent(player, amount, duration, currentTime);
        emit StakeDetails(player, amount, duration, unlockTime, previousStake, playerData.stakedAmount);
        emit VaultStakeUpdated(previousVaultStaked, vault.stakedAmount, amount);
    }
    
    /**
     * @dev Restake - extend lock period for existing stake
     * @param additionalDuration Additional lock duration to add
     */
    function restake(uint256 additionalDuration) 
        external 
        whenNotPaused
        validDuration(additionalDuration)
    {
        address player = msg.sender;
        PlayerAccount storage playerData = players[player];
        
        require(playerData.stakedAmount > 0, "No active stake");
        
        // Calculate and add accumulated rewards
        uint256 accumulatedRewards = _calculateRewards(player);
        playerData.rewardAmount += accumulatedRewards;
        
        // Extend duration
        playerData.durationTime += additionalDuration;
        playerData.rewardTime = block.timestamp;
        
        uint256 unlockTime = playerData.stakedTime + playerData.durationTime;
        
        emit StakeDetails(
            player,
            0, // No new amount added
            playerData.durationTime,
            unlockTime,
            playerData.stakedAmount,
            playerData.stakedAmount
        );
    }
    
    /**
     * @dev Add to existing stake
     * Keeps the same lock duration, adds more HBAR
     */
    function addToStake() 
        external 
        payable 
        whenNotPaused
        validStakeAmount(msg.value)
    {
        address player = msg.sender;
        uint256 amount = msg.value;
        
        PlayerAccount storage playerData = players[player];
        require(playerData.stakedAmount > 0, "No active stake to add to");
        
        uint256 currentTime = block.timestamp;
        
        // Calculate and add accumulated rewards
        uint256 accumulatedRewards = _calculateRewards(player);
        playerData.rewardAmount += accumulatedRewards;
        
        // Add to stake
        uint256 previousStake = playerData.stakedAmount;
        playerData.stakedAmount += amount;
        playerData.rewardTime = currentTime;
        
        // Update vault
        uint256 previousVaultStaked = vault.stakedAmount;
        vault.stakedAmount += amount;
        
        uint256 unlockTime = playerData.stakedTime + playerData.durationTime;
        
        emit SolStakeEvent(player, amount, playerData.durationTime, currentTime);
        emit StakeDetails(player, amount, playerData.durationTime, unlockTime, previousStake, playerData.stakedAmount);
        emit VaultStakeUpdated(previousVaultStaked, vault.stakedAmount, amount);
    }
    
    /**
     * @dev Internal function to calculate rewards
     * @param player Player address
     * @return rewards Calculated rewards
     */
    function _calculateRewards(address player) internal view returns (uint256 rewards) {
        PlayerAccount memory playerData = players[player];
        
        if (playerData.stakedAmount == 0) {
            return 0;
        }
        
        uint256 timeStaked = block.timestamp - playerData.rewardTime;
        
        // Formula: (stakedAmount * apyRate * timeStaked) / (365 days * 10000)
        rewards = (playerData.stakedAmount * vault.apyRate * timeStaked) / (365 days * 10000);
    }
    
    /**
     * @dev Get stake information for a player
     * @param player Player address
     * @return stakedAmount Amount currently staked
     * @return stakedTime When stake was made
     * @return durationTime Lock duration
     * @return unlockTime When stake unlocks
     * @return pendingRewards Current pending rewards
     * @return isLocked Whether stake is currently locked
     */
    function getStakeInfo(address player)
        external
        view
        returns (
            uint256 stakedAmount,
            uint256 stakedTime,
            uint256 durationTime,
            uint256 unlockTime,
            uint256 pendingRewards,
            bool isLocked
        )
    {
        PlayerAccount memory playerData = players[player];
        
        stakedAmount = playerData.stakedAmount;
        stakedTime = playerData.stakedTime;
        durationTime = playerData.durationTime;
        unlockTime = stakedTime + durationTime;
        pendingRewards = _calculateRewards(player) + playerData.rewardAmount;
        isLocked = block.timestamp < unlockTime;
    }
    
    /**
     * @dev Check if player has an active stake
     * @param player Player address
     * @return hasStake True if player has staked amount > 0
     */
    function hasActiveStake(address player) external view returns (bool hasStake) {
        hasStake = players[player].stakedAmount > 0;
    }
    
    /**
     * @dev Get vault statistics
     * @return totalStaked Total amount staked in vault
     * @return totalStakersCount Number of active stakers
     * @return currentApyRate Current APY rate
     * @return contractBalance Total contract balance
     */
    function getVaultStats()
        external
        view
        returns (
            uint256 totalStaked,
            uint256 totalStakersCount,
            uint256 currentApyRate,
            uint256 contractBalance
        )
    {
        totalStaked = vault.stakedAmount;
        totalStakersCount = totalStakers;
        currentApyRate = vault.apyRate;
        contractBalance = address(this).balance;
    }
    
    /**
     * @dev Pause staking (admin only)
     */
    function pauseStaking() external {
        require(msg.sender == vault.authority, "Only authority");
        paused = true;
    }
    
    /**
     * @dev Unpause staking (admin only)
     */
    function unpauseStaking() external {
        require(msg.sender == vault.authority, "Only authority");
        paused = false;
    }
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

/**
 * @title CompleteStakingStake
 * @dev Full implementation with reentrancy protection
 */
abstract contract CompleteStakingStake is StakingStake, ReentrancyGuard {
    
    /**
     * @dev Override stake with reentrancy protection
     */
    function stake(uint256 duration) 
        external 
        payable 
        override 
        nonReentrant 
    {
        super.stake(duration);
    }
    
    /**
     * @dev Override addToStake with reentrancy protection
     */
    function addToStake() 
        external 
        payable 
        override 
        nonReentrant 
    {
        super.addToStake();
    }
}

/**
 * @title StakingDurations
 * @dev Helper library for common staking durations
 */
library StakingDurations {
    uint256 internal constant DURATION_7_DAYS = 7 days;
    uint256 internal constant DURATION_14_DAYS = 14 days;
    uint256 internal constant DURATION_30_DAYS = 30 days;
    uint256 internal constant DURATION_90_DAYS = 90 days;
    uint256 internal constant DURATION_180_DAYS = 180 days;
    uint256 internal constant DURATION_365_DAYS = 365 days;
    
    /**
     * @dev Get duration by index
     * @param index Duration index (0-5)
     * @return duration Duration in seconds
     */
    function getDuration(uint256 index) internal pure returns (uint256 duration) {
        if (index == 0) return DURATION_7_DAYS;
        if (index == 1) return DURATION_14_DAYS;
        if (index == 2) return DURATION_30_DAYS;
        if (index == 3) return DURATION_90_DAYS;
        if (index == 4) return DURATION_180_DAYS;
        if (index == 5) return DURATION_365_DAYS;
        revert("Invalid duration index");
    }
}