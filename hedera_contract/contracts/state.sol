// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HederaStakingStructures
 * @dev State structures for Hedera staking contract
 * Converted from Solana Anchor account structures
 */

/**
 * @dev VaultAccount - Manages the main staking vault
 * Equivalent to Solana's VaultAccount with PDA seed "vault"
 */
struct VaultAccount {
    address authority;      // Authority/admin address (Pubkey -> address)
    uint256 stakedAmount;   // Total amount staked in the vault (u64 -> uint256)
    uint256 apyRate;        // APY rate in basis points (u64 -> uint256)
}

/**
 * @dev PlayerAccount - Individual staker account
 * Equivalent to Solana's PlayerAccount with PDA seed "player"
 */
struct PlayerAccount {
    uint256 stakedTime;     // Timestamp when stake was made (u64 -> uint256)
    uint256 stakedAmount;   // Amount staked by player (u64 -> uint256)
    uint256 rewardTime;     // Last reward calculation time (u64 -> uint256)
    uint256 durationTime;   // Staking duration in seconds (u64 -> uint256)
    uint256 rewardAmount;   // Accumulated rewards (u64 -> uint256)
}

/**
 * @dev TokenDetails - Token metadata structure
 * Used for potential token integration or metadata storage
 */
struct TokenDetails {
    string name;            // Token name
    string symbol;          // Token symbol
    string uri;             // Metadata URI
    uint256 initialSupply;  // Initial token supply (u64 -> uint256)
}

/**
 * @title HederaStakingStorage
 * @dev Enhanced staking contract with structured state management
 */
contract HederaStakingStorage {
    // Vault state
    VaultAccount public vault;
    
    // Player accounts mapping (address -> PlayerAccount)
    // Replaces Solana's PDA system: [b"player", authority, player_pubkey]
    mapping(address => PlayerAccount) public players;
    
    // Token details (if needed for future token integration)
    TokenDetails public tokenDetails;
    
    // Additional state variables
    bool public initialized;
    uint256 public totalPlayers;
    
    // Constants for validation
    uint256 public constant MIN_STAKE_AMOUNT = 1e8;      // 1 HBAR minimum
    uint256 public constant MAX_STAKE_AMOUNT = 1e14;     // 1,000,000 HBAR maximum
    uint256 public constant MIN_DURATION = 7 days;        // Minimum 7 days
    uint256 public constant MAX_DURATION = 365 days;      // Maximum 365 days
    uint256 public constant MIN_APY = 100;                // 1% minimum APY
    uint256 public constant MAX_APY = 100000;             // 1000% maximum APY
    
    // Events
    event VaultInitialized(address indexed authority, uint256 apyRate);
    event PlayerStaked(address indexed player, uint256 amount, uint256 duration);
    event PlayerUnstaked(address indexed player, uint256 amount);
    event RewardsClaimed(address indexed player, uint256 amount);
    event ApyUpdated(uint256 oldRate, uint256 newRate);
    event TokenDetailsUpdated(string name, string symbol);
    
    // Modifiers
    modifier onlyAuthority() {
        require(msg.sender == vault.authority, "Only authority");
        _;
    }
    
    modifier isInitialized() {
        require(initialized, "Not initialized");
        _;
    }
    
    modifier validStakeAmount(uint256 amount) {
        require(amount >= MIN_STAKE_AMOUNT, "Amount too low");
        require(amount <= MAX_STAKE_AMOUNT, "Amount too high");
        _;
    }
    
    modifier validDuration(uint256 duration) {
        require(duration >= MIN_DURATION, "Duration too short");
        require(duration <= MAX_DURATION, "Duration too long");
        _;
    }
    
    /**
     * @dev Constructor - Initialize vault authority
     */
    constructor() {
        vault.authority = msg.sender;
    }
    
    /**
     * @dev Initialize the vault with APY rate
     * @param _apyRate APY rate in basis points
     */
    function initialize(uint256 _apyRate) external onlyAuthority {
        require(!initialized, "Already initialized");
        require(_apyRate >= MIN_APY && _apyRate <= MAX_APY, "Invalid APY");
        
        vault.apyRate = _apyRate;
        vault.stakedAmount = 0;
        initialized = true;
        
        emit VaultInitialized(vault.authority, _apyRate);
    }
    
    /**
     * @dev Get vault account data
     * @return authority The vault authority address
     * @return stakedAmount Total staked amount in vault
     * @return apyRate Current APY rate
     */
    function getVaultAccount() external view returns (
        address authority,
        uint256 stakedAmount,
        uint256 apyRate
    ) {
        return (
            vault.authority,
            vault.stakedAmount,
            vault.apyRate
        );
    }
    
    /**
     * @dev Get player account data
     * @param _player Player address
     * @return stakedTime When the stake was made
     * @return stakedAmount Amount staked by player
     * @return rewardTime Last reward calculation time
     * @return durationTime Staking duration
     * @return rewardAmount Accumulated rewards
     */
    function getPlayerAccount(address _player) external view returns (
        uint256 stakedTime,
        uint256 stakedAmount,
        uint256 rewardTime,
        uint256 durationTime,
        uint256 rewardAmount
    ) {
        PlayerAccount memory player = players[_player];
        return (
            player.stakedTime,
            player.stakedAmount,
            player.rewardTime,
            player.durationTime,
            player.rewardAmount
        );
    }
    
    /**
     * @dev Check if a player has an active stake
     * @param _player Player address
     * @return bool True if player has active stake
     */
    function hasActiveStake(address _player) external view returns (bool) {
        return players[_player].stakedAmount > 0;
    }
    
    /**
     * @dev Get total number of stakers
     * @return uint256 Total players count
     */
    function getTotalPlayers() external view returns (uint256) {
        return totalPlayers;
    }
    
    /**
     * @dev Set token details (for future token integration)
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _uri Metadata URI
     * @param _initialSupply Initial supply
     */
    function setTokenDetails(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        uint256 _initialSupply
    ) external onlyAuthority {
        tokenDetails = TokenDetails({
            name: _name,
            symbol: _symbol,
            uri: _uri,
            initialSupply: _initialSupply
        });
        
        emit TokenDetailsUpdated(_name, _symbol);
    }
    
    /**
     * @dev Get token details
     * @return name Token name
     * @return symbol Token symbol
     * @return uri Metadata URI
     * @return initialSupply Initial supply
     */
    function getTokenDetails() external view returns (
        string memory name,
        string memory symbol,
        string memory uri,
        uint256 initialSupply
    ) {
        return (
            tokenDetails.name,
            tokenDetails.symbol,
            tokenDetails.uri,
            tokenDetails.initialSupply
        );
    }
    
    /**
     * @dev Update vault APY rate
     * @param _newRate New APY rate in basis points
     */
    function updateApyRate(uint256 _newRate) external onlyAuthority isInitialized {
        require(_newRate >= MIN_APY && _newRate <= MAX_APY, "Invalid APY");
        
        uint256 oldRate = vault.apyRate;
        vault.apyRate = _newRate;
        
        emit ApyUpdated(oldRate, _newRate);
    }
    
    /**
     * @dev Transfer authority to new address
     * @param _newAuthority New authority address
     */
    function transferAuthority(address _newAuthority) external onlyAuthority {
        require(_newAuthority != address(0), "Invalid address");
        require(_newAuthority != vault.authority, "Same authority");
        
        vault.authority = _newAuthority;
    }
    
    /**
     * @dev Calculate space/storage used (for reference)
     * Not directly applicable in Solidity but useful for understanding storage
     * @return vaultSize Approximate vault storage size
     * @return playerSize Approximate player account storage size
     */
    function getStorageInfo() external pure returns (
        uint256 vaultSize,
        uint256 playerSize
    ) {
        // VaultAccount: address(20) + uint256(32) + uint256(32) = 84 bytes
        // PlayerAccount: uint256(32) * 5 = 160 bytes
        return (84, 160);
    }
}

/**
 * @title StakingConstants
 * @dev Library for staking-related constants
 */
library StakingConstants {
    // Time constants
    uint256 internal constant SECONDS_PER_DAY = 86400;
    uint256 internal constant SECONDS_PER_YEAR = 31536000; // 365 days
    
    // Precision
    uint256 internal constant BASIS_POINTS = 10000;
    uint256 internal constant PRECISION = 1e18;
    
    // Duration presets
    uint256 internal constant DURATION_7_DAYS = 7 days;
    uint256 internal constant DURATION_14_DAYS = 14 days;
    uint256 internal constant DURATION_30_DAYS = 30 days;
    uint256 internal constant DURATION_90_DAYS = 90 days;
    uint256 internal constant DURATION_180_DAYS = 180 days;
    uint256 internal constant DURATION_365_DAYS = 365 days;
    
    /**
     * @dev Get duration name
     * @param duration Duration in seconds
     * @return string Duration name
     */
    function getDurationName(uint256 duration) internal pure returns (string memory) {
        if (duration == DURATION_7_DAYS) return "7 Days";
        if (duration == DURATION_14_DAYS) return "14 Days";
        if (duration == DURATION_30_DAYS) return "30 Days";
        if (duration == DURATION_90_DAYS) return "90 Days";
        if (duration == DURATION_180_DAYS) return "180 Days";
        if (duration == DURATION_365_DAYS) return "365 Days";
        return "Custom";
    }
}