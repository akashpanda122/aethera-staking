// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HederaStaking
 * @dev HBAR staking contract with rewards mechanism
 * Converted from Solana Anchor program to Hedera-compatible Solidity
 */
contract HederaStaking {
    // State variables
    address public authority;
    uint256 public apyRate; // APY in basis points (e.g., 5000 = 50%)
    uint256 public totalStaked;
    bool public initialized;

    // Player account structure
    struct PlayerAccount {
        uint256 stakedAmount;
        uint256 stakedTime;
        uint256 durationTime;
        uint256 rewardAmount;
    }

    // Mappings
    mapping(address => PlayerAccount) public players;
    
    // Events
    event Initialized(address indexed authority, uint256 apyRate);
    event Staked(address indexed player, uint256 amount, uint256 duration);
    event Unstaked(address indexed player, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed player, uint256 amount);
    event ConfigUpdated(uint256 newApyRate);
    event Deposited(address indexed from, uint256 amount);
    event Withdrawn(address indexed to, uint256 amount);

    // Modifiers
    modifier onlyAuthority() {
        require(msg.sender == authority, "Only authority can call this function");
        _;
    }

    modifier isInitialized() {
        require(initialized, "Contract not initialized");
        _;
    }

    modifier notInitialized() {
        require(!initialized, "Contract already initialized");
        _;
    }

    /**
     * @dev Constructor - sets the contract deployer as authority
     */
    constructor() {
        authority = msg.sender;
    }

    /**
     * @dev Initialize the staking contract with APY rate
     * @param _apyRate APY rate in basis points (e.g., 5000 = 50%)
     */
    function initialize(uint256 _apyRate) external onlyAuthority notInitialized {
        require(_apyRate > 0 && _apyRate <= 100000, "Invalid APY rate"); // Max 1000%
        
        apyRate = _apyRate;
        initialized = true;
        
        emit Initialized(authority, _apyRate);
    }

    /**
     * @dev Stake HBAR with a specific duration
     * @param _duration Duration in seconds
     */
    function stake(uint256 _duration) external payable isInitialized {
        require(msg.value > 0, "Stake amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        
        PlayerAccount storage player = players[msg.sender];
        
        // If player already has stake, calculate and add existing rewards
        if (player.stakedAmount > 0) {
            uint256 existingRewards = calculateRewards(msg.sender);
            player.rewardAmount += existingRewards;
        }
        
        // Update player staking info
        player.stakedAmount += msg.value;
        player.stakedTime = block.timestamp;
        player.durationTime = _duration;
        
        totalStaked += msg.value;
        
        emit Staked(msg.sender, msg.value, _duration);
    }

    /**
     * @dev Unstake HBAR and claim all rewards
     */
    function unstake() external isInitialized {
        PlayerAccount storage player = players[msg.sender];
        require(player.stakedAmount > 0, "No staked amount");
        
        // Calculate rewards
        uint256 rewards = calculateRewards(msg.sender);
        uint256 totalAmount = player.stakedAmount + player.rewardAmount + rewards;
        
        require(address(this).balance >= totalAmount, "Insufficient contract balance");
        
        // Update state
        totalStaked -= player.stakedAmount;
        uint256 stakedAmount = player.stakedAmount;
        
        // Reset player account
        player.stakedAmount = 0;
        player.stakedTime = 0;
        player.durationTime = 0;
        player.rewardAmount = 0;
        
        // Transfer funds
        (bool success, ) = payable(msg.sender).call{value: totalAmount}("");
        require(success, "Transfer failed");
        
        emit Unstaked(msg.sender, stakedAmount, rewards);
    }

    /**
     * @dev Claim accumulated rewards without unstaking
     */
    function claimRewards() external isInitialized {
        PlayerAccount storage player = players[msg.sender];
        require(player.stakedAmount > 0, "No staked amount");
        
        uint256 rewards = calculateRewards(msg.sender);
        uint256 totalRewards = player.rewardAmount + rewards;
        
        require(totalRewards > 0, "No rewards to claim");
        require(address(this).balance >= totalRewards, "Insufficient contract balance");
        
        // Reset rewards and update stake time
        player.rewardAmount = 0;
        player.stakedTime = block.timestamp;
        
        // Transfer rewards
        (bool success, ) = payable(msg.sender).call{value: totalRewards}("");
        require(success, "Transfer failed");
        
        emit RewardsClaimed(msg.sender, totalRewards);
    }

    /**
     * @dev Update APY rate (admin only)
     * @param _newRate New APY rate in basis points
     */
    function config(uint256 _newRate) external onlyAuthority isInitialized {
        require(_newRate > 0 && _newRate <= 100000, "Invalid APY rate");
        
        apyRate = _newRate;
        
        emit ConfigUpdated(_newRate);
    }

    /**
     * @dev Deposit HBAR into contract (admin only)
     */
    function deposit() external payable onlyAuthority isInitialized {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw HBAR from contract (admin only)
     */
    function withdraw() external onlyAuthority isInitialized {
        uint256 availableBalance = address(this).balance - totalStaked;
        require(availableBalance > 0, "No available balance to withdraw");
        
        (bool success, ) = payable(authority).call{value: availableBalance}("");
        require(success, "Transfer failed");
        
        emit Withdrawn(authority, availableBalance);
    }

    /**
     * @dev Calculate current rewards for a player
     * @param _player Address of the player
     * @return Calculated reward amount
     */
    function calculateRewards(address _player) public view returns (uint256) {
        PlayerAccount memory player = players[_player];
        
        if (player.stakedAmount == 0) {
            return 0;
        }
        
        uint256 timeStaked = block.timestamp - player.stakedTime;
        
        // Calculate rewards: (stakedAmount * apyRate * timeStaked) / (365 days * 10000)
        // apyRate is in basis points, so divide by 10000
        uint256 rewards = (player.stakedAmount * apyRate * timeStaked) / (365 days * 10000);
        
        return rewards;
    }

    /**
     * @dev Get player account data
     * @param _player Address of the player
     * @return Player account details
     */
    function getPlayerData(address _player) external view returns (
        uint256 stakedAmount,
        uint256 stakedTime,
        uint256 durationTime,
        uint256 rewardAmount,
        uint256 currentRewards
    ) {
        PlayerAccount memory player = players[_player];
        uint256 pendingRewards = calculateRewards(_player);
        
        return (
            player.stakedAmount,
            player.stakedTime,
            player.durationTime,
            player.rewardAmount,
            pendingRewards
        );
    }

    /**
     * @dev Get contract statistics
     */
    function getContractStats() external view returns (
        uint256 contractBalance,
        uint256 totalStakedAmount,
        uint256 currentApyRate,
        address contractAuthority
    ) {
        return (
            address(this).balance,
            totalStaked,
            apyRate,
            authority
        );
    }

    /**
     * @dev Transfer authority to a new address
     * @param _newAuthority New authority address
     */
    function transferAuthority(address _newAuthority) external onlyAuthority {
        require(_newAuthority != address(0), "Invalid address");
        authority = _newAuthority;
    }

    /**
     * @dev Fallback function to receive HBAR
     */
    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }
}