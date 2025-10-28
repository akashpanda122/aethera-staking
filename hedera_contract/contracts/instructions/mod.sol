// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HederaStaking
 * @dev Complete staking contract for Hedera blockchain
 * Converted from Solana Anchor program with all instructions integrated
 * 
 * Modules converted:
 * - initialize: Contract initialization
 * - sol_stake: Stake HBAR with lock period
 * - sol_unstake: Unstake HBAR after lock period
 * - claim_rewards: Claim accumulated rewards
 * - config: Update configuration (APY)
 * - deposit: Admin deposit funds
 * - withdraw: Admin withdraw funds
 */

// ============================================
// STATE STRUCTURES
// ============================================

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

// ============================================
// CUSTOM ERRORS
// ============================================

error NotInitialized();
error AlreadyInitialized();
error OnlyAuthority(address caller, address expected);
error InvalidArgument(string parameter);
error AmountMustBeGreaterThanZero(string operation);
error InvalidDuration(uint256 duration, uint256 minDuration, uint256 maxDuration);
error InvalidApyRate(uint256 rate, uint256 minRate, uint256 maxRate);
error MinStakeNotMet(uint256 provided, uint256 minimum);
error MaxStakeExceeded(uint256 requested, uint256 maximum);
error NoStakeFound(address player);
error InsufficientBalance(uint256 required, uint256 available);
error InsufficientStake(uint256 requested, uint256 staked);
error InvalidUnstakeTime(uint256 currentTime, uint256 unlockTime, uint256 remainingTime);
error NoRewardsToClaim(address player);
error TransferFailed(address to, uint256 amount);
error ContractPaused();
error InsufficientContractBalance(uint256 required, uint256 available);

// ============================================
// MAIN CONTRACT
// ============================================

/**
 * @title HederaStaking
 * @dev Complete staking contract implementation
 */
contract HederaStaking {
    
    // ============================================
    // STATE VARIABLES
    // ============================================
    
    VaultAccount public vault;
    mapping(address => PlayerAccount) public players;
    
    bool public initialized;
    bool public paused;
    uint256 public totalStakers;
    
    // Constants
    uint256 public constant MIN_STAKE_AMOUNT = 1e8;      // 1 HBAR
    uint256 public constant MAX_STAKE_AMOUNT = 1e14;     // 1,000,000 HBAR
    uint256 public constant MIN_DURATION = 7 days;
    uint256 public constant MAX_DURATION = 365 days;
    uint256 public constant MIN_APY = 100;               // 1%
    uint256 public constant MAX_APY = 100000;            // 1000%
    
    // Reentrancy guard
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    
    // ============================================
    // EVENTS
    // ============================================
    
    event Initialized(address indexed authority, uint256 apyRate, uint256 timestamp);
    event SolStakeEvent(address indexed player, uint256 amount, uint256 duration, uint256 timestamp);
    event SolUnstakeEvent(address indexed player, uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed player, uint256 amount, uint256 timestamp);
    event ApyConfigured(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event Deposited(address indexed from, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed to, uint256 amount, uint256 timestamp);
    event ContractPausedEvent(address indexed by, uint256 timestamp);
    event ContractUnpausedEvent(address indexed by, uint256 timestamp);
    
    // ============================================
    // MODIFIERS
    // ============================================
    
    modifier onlyAuthority() {
        if (msg.sender != vault.authority) {
            revert OnlyAuthority(msg.sender, vault.authority);
        }
        _;
    }
    
    modifier isInitialized() {
        if (!initialized) revert NotInitialized();
        _;
    }
    
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }
    
    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrancy detected");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor() {
        vault.authority = msg.sender;
        _status = _NOT_ENTERED;
    }
    
    // ============================================
    // INITIALIZE (from initialize.rs)
    // ============================================
    
    /**
     * @dev Initialize the staking contract
     * @param _apyRate APY rate in basis points (e.g., 5000 = 50%)
     */
    function initialize(uint256 _apyRate) external onlyAuthority {
        if (initialized) revert AlreadyInitialized();
        if (_apyRate < MIN_APY || _apyRate > MAX_APY) {
            revert InvalidApyRate(_apyRate, MIN_APY, MAX_APY);
        }
        
        vault.apyRate = _apyRate;
        vault.stakedAmount = 0;
        initialized = true;
        
        emit Initialized(vault.authority, _apyRate, block.timestamp);
    }
    
    // ============================================
    // SOL_STAKE (from sol_stake.rs)
    // ============================================
    
    /**
     * @dev Stake HBAR with lock period
     * @param duration Lock duration in seconds
     */
    function stake(uint256 duration) 
        external 
        payable 
        isInitialized
        whenNotPaused
        nonReentrant
    {
        uint256 amount = msg.value;
        address player = msg.sender;
        
        // Validations
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero("stake");
        }
        if (amount < MIN_STAKE_AMOUNT) {
            revert MinStakeNotMet(amount, MIN_STAKE_AMOUNT);
        }
        if (amount > MAX_STAKE_AMOUNT) {
            revert MaxStakeExceeded(amount, MAX_STAKE_AMOUNT);
        }
        if (duration < MIN_DURATION || duration > MAX_DURATION) {
            revert InvalidDuration(duration, MIN_DURATION, MAX_DURATION);
        }
        
        PlayerAccount storage playerData = players[player];
        uint256 currentTime = block.timestamp;
        
        // Track new stakers
        if (playerData.stakedAmount == 0) {
            totalStakers++;
        } else {
            // Add accumulated rewards if restaking
            uint256 accumulatedRewards = _calculateRewards(player);
            playerData.rewardAmount += accumulatedRewards;
        }
        
        // Update player data
        playerData.stakedAmount += amount;
        playerData.stakedTime = currentTime;
        playerData.durationTime = duration;
        playerData.rewardTime = currentTime;
        
        // Update vault
        vault.stakedAmount += amount;
        
        emit SolStakeEvent(player, amount, duration, currentTime);
    }
    
    // ============================================
    // SOL_UNSTAKE (from sol_unstake.rs)
    // ============================================
    
    /**
     * @dev Unstake HBAR after lock period
     */
    function unstake() 
        external 
        isInitialized
        nonReentrant
    {
        address player = msg.sender;
        PlayerAccount storage playerData = players[player];
        
        // Validate stake exists
        if (playerData.stakedAmount == 0) {
            revert NoStakeFound(player);
        }
        
        // Check lock period
        uint256 currentTime = block.timestamp;
        uint256 expiredTime = playerData.stakedTime + playerData.durationTime;
        
        if (expiredTime > currentTime) {
            uint256 remainingTime = expiredTime - currentTime;
            revert InvalidUnstakeTime(currentTime, expiredTime, remainingTime);
        }
        
        // Calculate amounts
        uint256 amount = playerData.stakedAmount;
        uint256 rewards = _calculateRewards(player);
        uint256 totalAmount = amount + rewards;
        
        // Update vault
        if (vault.stakedAmount < amount) {
            revert InsufficientStake(amount, vault.stakedAmount);
        }
        vault.stakedAmount -= amount;
        
        // Reset player data
        playerData.stakedAmount = 0;
        playerData.stakedTime = 0;
        playerData.durationTime = 0;
        playerData.rewardTime = 0;
        playerData.rewardAmount = 0;
        
        totalStakers--;
        
        // Check contract balance
        if (address(this).balance < totalAmount) {
            revert InsufficientBalance(totalAmount, address(this).balance);
        }
        
        // Transfer
        (bool success, ) = payable(player).call{value: totalAmount}("");
        if (!success) revert TransferFailed(player, totalAmount);
        
        emit SolUnstakeEvent(player, amount, block.timestamp);
    }
    
    // ============================================
    // CLAIM_REWARDS (from claim_rewards.rs)
    // ============================================
    
    /**
     * @dev Claim accumulated rewards without unstaking
     */
    function claimRewards() 
        external 
        isInitialized
        nonReentrant
    {
        address player = msg.sender;
        PlayerAccount storage playerData = players[player];
        
        if (playerData.stakedAmount == 0) {
            revert NoStakeFound(player);
        }
        
        // Calculate total rewards
        uint256 rewards = _calculateRewards(player);
        uint256 totalRewards = playerData.rewardAmount + rewards;
        
        if (totalRewards == 0) {
            revert NoRewardsToClaim(player);
        }
        
        // Check balance
        if (address(this).balance < totalRewards) {
            revert InsufficientContractBalance(totalRewards, address(this).balance);
        }
        
        // Reset rewards and update time
        playerData.rewardAmount = 0;
        playerData.rewardTime = block.timestamp;
        
        // Transfer rewards
        (bool success, ) = payable(player).call{value: totalRewards}("");
        if (!success) revert TransferFailed(player, totalRewards);
        
        emit RewardsClaimed(player, totalRewards, block.timestamp);
    }
    
    // ============================================
    // CONFIG (from config.rs)
    // ============================================
    
    /**
     * @dev Update APY rate
     * @param rate New APY rate in basis points
     */
    function config(uint256 rate) 
        external 
        onlyAuthority
        isInitialized
    {
        if (rate < MIN_APY || rate > MAX_APY) {
            revert InvalidApyRate(rate, MIN_APY, MAX_APY);
        }
        
        uint256 oldRate = vault.apyRate;
        vault.apyRate = rate;
        
        emit ApyConfigured(oldRate, rate, block.timestamp);
    }
    
    // ============================================
    // DEPOSIT (from deposit.rs)
    // ============================================
    
    /**
     * @dev Admin deposit funds into contract
     */
    function deposit() 
        external 
        payable 
        onlyAuthority
        isInitialized
    {
        if (msg.value == 0) {
            revert AmountMustBeGreaterThanZero("deposit");
        }
        
        emit Deposited(msg.sender, msg.value, block.timestamp);
    }
    
    // ============================================
    // WITHDRAW (from withdraw.rs)
    // ============================================
    
    /**
     * @dev Admin withdraw available funds
     * Only withdraws excess (not staked funds)
     */
    function withdraw() 
        external 
        onlyAuthority
        isInitialized
        nonReentrant
    {
        uint256 contractBalance = address(this).balance;
        uint256 stakedAmount = vault.stakedAmount;
        
        // Calculate available balance
        if (contractBalance <= stakedAmount) {
            revert InsufficientContractBalance(1, 0);
        }
        
        uint256 availableBalance = contractBalance - stakedAmount;
        
        // Transfer to authority
        (bool success, ) = payable(vault.authority).call{value: availableBalance}("");
        if (!success) revert TransferFailed(vault.authority, availableBalance);
        
        emit Withdrawn(vault.authority, availableBalance, block.timestamp);
    }
    
    /**
     * @dev Admin withdraw specific amount
     * @param amount Amount to withdraw
     */
    function withdrawAmount(uint256 amount) 
        external 
        onlyAuthority
        isInitialized
        nonReentrant
    {
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero("withdraw");
        }
        
        uint256 contractBalance = address(this).balance;
        uint256 availableBalance = contractBalance - vault.stakedAmount;
        
        if (amount > availableBalance) {
            revert InsufficientContractBalance(amount, availableBalance);
        }
        
        (bool success, ) = payable(vault.authority).call{value: amount}("");
        if (!success) revert TransferFailed(vault.authority, amount);
        
        emit Withdrawn(vault.authority, amount, block.timestamp);
    }
    
    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    /**
     * @dev Calculate rewards for a player
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
     * @dev Calculate current rewards (public view)
     * @param player Player address
     * @return Current pending rewards
     */
    function calculateRewards(address player) external view returns (uint256) {
        PlayerAccount memory playerData = players[player];
        uint256 pendingRewards = _calculateRewards(player);
        return playerData.rewardAmount + pendingRewards;
    }
    
    // ============================================
    // VIEW FUNCTIONS
    // ============================================
    
    /**
     * @dev Get player account data
     * @param player Player address
     */
    function getPlayerData(address player)
        external
        view
        returns (
            uint256 stakedAmount,
            uint256 stakedTime,
            uint256 durationTime,
            uint256 rewardAmount,
            uint256 currentRewards
        )
    {
        PlayerAccount memory playerData = players[player];
        uint256 pendingRewards = _calculateRewards(player);
        
        return (
            playerData.stakedAmount,
            playerData.stakedTime,
            playerData.durationTime,
            playerData.rewardAmount,
            pendingRewards
        );
    }
    
    /**
     * @dev Get vault account data
     */
    function getVaultAccount()
        external
        view
        returns (
            address authority,
            uint256 stakedAmount,
            uint256 apyRate
        )
    {
        return (
            vault.authority,
            vault.stakedAmount,
            vault.apyRate
        );
    }
    
    /**
     * @dev Get contract statistics
     */
    function getContractStats()
        external
        view
        returns (
            uint256 totalStaked,
            uint256 totalStakersCount,
            uint256 contractBalance,
            uint256 availableBalance,
            uint256 currentApyRate,
            bool isPaused
        )
    {
        uint256 balance = address(this).balance;
        uint256 available = balance > vault.stakedAmount ? balance - vault.stakedAmount : 0;
        
        return (
            vault.stakedAmount,
            totalStakers,
            balance,
            available,
            vault.apyRate,
            paused
        );
    }
    
    /**
     * @dev Check if player can unstake
     * @param player Player address
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
    
    // ============================================
    // ADMIN FUNCTIONS
    // ============================================
    
    /**
     * @dev Pause contract
     */
    function pause() external onlyAuthority {
        paused = true;
        emit ContractPausedEvent(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyAuthority {
        paused = false;
        emit ContractUnpausedEvent(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Transfer authority
     * @param newAuthority New authority address
     */
    function transferAuthority(address newAuthority) external onlyAuthority {
        if (newAuthority == address(0)) {
            revert InvalidArgument("newAuthority");
        }
        vault.authority = newAuthority;
    }
    
    // ============================================
    // FALLBACK
    // ============================================
    
    /**
     * @dev Receive function to accept HBAR
     */
    receive() external payable {
        emit Deposited(msg.sender, msg.value, block.timestamp);
    }
}