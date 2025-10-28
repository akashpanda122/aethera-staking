// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HederaStakingUnstake
 * @dev Unstake functionality for Hedera staking contract
 * Converted from Solana Anchor sol_unstake instruction
 */

// Import required structures and errors
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
error InvalidUnstakeTime(uint256 currentTime, uint256 unlockTime, uint256 remainingTime);
error NoStakeFound(address player);
error InsufficientBalance(uint256 required, uint256 available);
error TransferFailed(address to, uint256 amount);
error InsufficientStake(uint256 requested, uint256 staked);

/**
 * @title StakingUnstake
 * @dev Contract module for unstaking functionality
 */
abstract contract StakingUnstake {
    
    // State variables
    VaultAccount internal vault;
    mapping(address => PlayerAccount) internal players;
    
    // Events
    /**
     * @dev Emitted when a player unstakes
     * @param player Address that unstaked
     * @param amount Amount unstaked in tinybars
     * @param timestamp Time of unstake
     */
    event SolUnstakeEvent(
        address indexed player,
        uint256 amount,
        uint256 timestamp
    );
    
    /**
     * @dev Detailed unstake event
     * @param player Player address
     * @param stakedAmount Amount that was staked
     * @param rewards Reward amount claimed
     * @param totalAmount Total amount transferred (stake + rewards)
     * @param stakedTime Original stake time
     * @param unstakeTime Unstake time
     */
    event UnstakeDetails(
        address indexed player,
        uint256 stakedAmount,
        uint256 rewards,
        uint256 totalAmount,
        uint256 stakedTime,
        uint256 unstakeTime
    );
    
    /**
     * @dev Emitted when vault accounting is updated
     * @param previousStaked Previous total staked amount
     * @param newStaked New total staked amount
     * @param amountRemoved Amount removed from vault
     */
    event VaultUpdated(
        uint256 previousStaked,
        uint256 newStaked,
        uint256 amountRemoved
    );
    
    /**
     * @dev Unstake tokens - main function
     * Equivalent to Solana's sol_unstake instruction
     * 
     * Requirements:
     * - Player must have an active stake
     * - Lock period must have expired
     * - Contract must have sufficient balance
     */
    function unstake() external {
        // Grab data from storage (equivalent to ctx.accounts)
        address player = msg.sender;
        PlayerAccount storage playerData = players[player];
        
        // Validate player has stake
        if (playerData.stakedAmount == 0) {
            revert NoStakeFound(player);
        }
        
        // Get current time (equivalent to Clock::get().unwrap().unix_timestamp)
        uint256 currentTime = block.timestamp;
        
        // Calculate expiration time
        uint256 expiredTime = playerData.stakedTime + playerData.durationTime;
        
        // Check if lock period has expired
        if (expiredTime > currentTime) {
            uint256 remainingTime = expiredTime - currentTime;
            revert InvalidUnstakeTime(currentTime, expiredTime, remainingTime);
        }
        
        // Get the staked amount
        uint256 amount = playerData.stakedAmount;
        
        // Calculate any accumulated rewards
        uint256 rewards = calculateRewards(player);
        uint256 totalAmount = amount + rewards;
        
        // Log the unstake amount (equivalent to msg! macro)
        // In Solidity, we use events for logging
        
        // Update vault accounting
        uint256 previousVaultStaked = vault.stakedAmount;
        
        if (vault.stakedAmount < amount) {
            revert InsufficientStake(amount, vault.stakedAmount);
        }
        
        vault.stakedAmount -= amount;
        
        // Update player accounting - reset to zero
        playerData.stakedAmount = 0;
        playerData.stakedTime = 0;
        playerData.durationTime = 0;
        playerData.rewardTime = 0;
        playerData.rewardAmount = 0;
        
        // Check contract has sufficient balance
        if (address(this).balance < totalAmount) {
            revert InsufficientBalance(totalAmount, address(this).balance);
        }
        
        // Transfer HBAR to player (equivalent to transfer_lamports_from_owned_pda)
        (bool success, ) = payable(player).call{value: totalAmount}("");
        if (!success) {
            revert TransferFailed(player, totalAmount);
        }
        
        // Emit events
        emit SolUnstakeEvent(
            player,
            amount,
            block.timestamp
        );
        
        emit UnstakeDetails(
            player,
            amount,
            rewards,
            totalAmount,
            playerData.stakedTime,
            block.timestamp
        );
        
        emit VaultUpdated(
            previousVaultStaked,
            vault.stakedAmount,
            amount
        );
    }
    
    /**
     * @dev Emergency unstake - unstake before lock period expires
     * Applies penalty for early withdrawal
     * @param penaltyRate Penalty rate in basis points (e.g., 1000 = 10%)
     */
    function emergencyUnstake(uint256 penaltyRate) external {
        address player = msg.sender;
        PlayerAccount storage playerData = players[player];
        
        if (playerData.stakedAmount == 0) {
            revert NoStakeFound(player);
        }
        
        uint256 amount = playerData.stakedAmount;
        
        // Calculate penalty
        uint256 penalty = (amount * penaltyRate) / 10000;
        uint256 amountAfterPenalty = amount - penalty;
        
        // Update accounting
        vault.stakedAmount -= amount;
        playerData.stakedAmount = 0;
        playerData.stakedTime = 0;
        playerData.durationTime = 0;
        playerData.rewardTime = 0;
        playerData.rewardAmount = 0;
        
        // Transfer reduced amount to player
        if (address(this).balance < amountAfterPenalty) {
            revert InsufficientBalance(amountAfterPenalty, address(this).balance);
        }
        
        (bool success, ) = payable(player).call{value: amountAfterPenalty}("");
        if (!success) {
            revert TransferFailed(player, amountAfterPenalty);
        }
        
        emit SolUnstakeEvent(player, amountAfterPenalty, block.timestamp);
    }
    
    /**
     * @dev Unstake specific amount (partial unstake)
     * @param amount Amount to unstake
     */
    function unstakeAmount(uint256 amount) external {
        address player = msg.sender;
        PlayerAccount storage playerData = players[player];
        
        if (playerData.stakedAmount == 0) {
            revert NoStakeFound(player);
        }
        
        if (amount > playerData.stakedAmount) {
            revert InsufficientStake(amount, playerData.stakedAmount);
        }
        
        // Check lock period
        uint256 currentTime = block.timestamp;
        uint256 expiredTime = playerData.stakedTime + playerData.durationTime;
        
        if (expiredTime > currentTime) {
            uint256 remainingTime = expiredTime - currentTime;
            revert InvalidUnstakeTime(currentTime, expiredTime, remainingTime);
        }
        
        // Calculate proportional rewards
        uint256 totalRewards = calculateRewards(player);
        uint256 proportionalRewards = (totalRewards * amount) / playerData.stakedAmount;
        uint256 totalAmount = amount + proportionalRewards;
        
        // Update accounting
        vault.stakedAmount -= amount;
        playerData.stakedAmount -= amount;
        
        // If fully unstaked, reset everything
        if (playerData.stakedAmount == 0) {
            playerData.stakedTime = 0;
            playerData.durationTime = 0;
            playerData.rewardTime = 0;
            playerData.rewardAmount = 0;
        } else {
            // Update reward time for remaining stake
            playerData.rewardTime = block.timestamp;
        }
        
        // Transfer
        if (address(this).balance < totalAmount) {
            revert InsufficientBalance(totalAmount, address(this).balance);
        }
        
        (bool success, ) = payable(player).call{value: totalAmount}("");
        if (!success) {
            revert TransferFailed(player, totalAmount);
        }
        
        emit SolUnstakeEvent(player, amount, block.timestamp);
        emit UnstakeDetails(
            player,
            amount,
            proportionalRewards,
            totalAmount,
            playerData.stakedTime,
            block.timestamp
        );
    }
    
    /**
     * @dev Calculate rewards for a player
     * @param player Player address
     * @return rewards Calculated reward amount
     */
    function calculateRewards(address player) internal view returns (uint256 rewards) {
        PlayerAccount memory playerData = players[player];
        
        if (playerData.stakedAmount == 0) {
            return 0;
        }
        
        uint256 timeStaked = block.timestamp - playerData.rewardTime;
        
        // Formula: (stakedAmount * apyRate * timeStaked) / (365 days * 10000)
        rewards = (playerData.stakedAmount * vault.apyRate * timeStaked) / (365 days * 10000);
        
        // Add any previously accumulated rewards
        rewards += playerData.rewardAmount;
    }
    
    /**
     * @dev Check if player can unstake
     * @param player Player address
     * @return canUnstake True if unstaking is allowed
     * @return unlockTime Time when unstaking becomes available
     * @return remainingTime Seconds until unlock (0 if already unlocked)
     */
    function canUnstake(address player) 
        external 
        view 
        returns (
            bool canUnstake,
            uint256 unlockTime,
            uint256 remainingTime
        ) 
    {
        PlayerAccount memory playerData = players[player];
        
        if (playerData.stakedAmount == 0) {
            return (false, 0, 0);
        }
        
        unlockTime = playerData.stakedTime + playerData.durationTime;
        
        if (block.timestamp >= unlockTime) {
            canUnstake = true;
            remainingTime = 0;
        } else {
            canUnstake = false;
            remainingTime = unlockTime - block.timestamp;
        }
    }
    
    /**
     * @dev Get player unstake info
     * @param player Player address
     * @return stakedAmount Amount currently staked
     * @return pendingRewards Pending reward amount
     * @return totalAmount Total amount (stake + rewards)
     * @return unlockTime When unstaking becomes available
     * @return isUnlocked Whether currently unlocked
     */
    function getUnstakeInfo(address player)
        external
        view
        returns (
            uint256 stakedAmount,
            uint256 pendingRewards,
            uint256 totalAmount,
            uint256 unlockTime,
            bool isUnlocked
        )
    {
        PlayerAccount memory playerData = players[player];
        
        stakedAmount = playerData.stakedAmount;
        pendingRewards = calculateRewards(player);
        totalAmount = stakedAmount + pendingRewards;
        unlockTime = playerData.stakedTime + playerData.durationTime;
        isUnlocked = block.timestamp >= unlockTime;
    }
    
    /**
     * @dev Get time remaining until unlock
     * @param player Player address
     * @return timeRemaining Seconds until unlock (0 if unlocked)
     */
    function getTimeUntilUnlock(address player) 
        external 
        view 
        returns (uint256 timeRemaining) 
    {
        PlayerAccount memory playerData = players[player];
        
        if (playerData.stakedAmount == 0) {
            return 0;
        }
        
        uint256 unlockTime = playerData.stakedTime + playerData.durationTime;
        
        if (block.timestamp >= unlockTime) {
            return 0;
        }
        
        timeRemaining = unlockTime - block.timestamp;
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
 * @title CompleteStakingUnstake
 * @dev Full implementation with reentrancy protection
 */
abstract contract CompleteStakingUnstake is StakingUnstake, ReentrancyGuard {
    
    /**
     * @dev Override unstake with reentrancy protection
     */
    function unstake() external override nonReentrant {
        super.unstake();
    }
    
    /**
     * @dev Override unstakeAmount with reentrancy protection
     */
    function unstakeAmount(uint256 amount) external override nonReentrant {
        super.unstakeAmount(amount);
    }
    
    /**
     * @dev Override emergencyUnstake with reentrancy protection
     */
    function emergencyUnstake(uint256 penaltyRate) external override nonReentrant {
        super.emergencyUnstake(penaltyRate);
    }
}