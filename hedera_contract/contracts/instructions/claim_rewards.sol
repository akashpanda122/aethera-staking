// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vault
 * @notice This contract holds staking data and configuration.
 * It allows players to claim HBAR rewards based on their staked amount.
 */
contract Vault {

    // --- State Variables ---

    address public authority;
    uint64 public apyRate;

    /**
     * @notice Represents the 'VaultAccount' or 'game_data'.
     * This variable tracks the total amount of HBAR available in the
     * contract to pay out as rewards.
     * This is the equivalent of 'game_data.staked_amount'.
     */
    uint256 public rewardPool;

    /**
     * @notice This struct represents the 'PlayerAccount' or 'player_data'
     * from your Rust code.
     */
    struct PlayerInfo {
        uint256 stakedAmount;   // The amount this player has staked.
        uint64  rewardTime;     // The timestamp of their last claim/stake.
        uint256 rewardAmount;   // The total rewards this player has ever claimed.
    }

    /**
     * @notice This mapping links a player's address to their staking data.
     * This is the Solidity equivalent of having many 'PlayerAccount' PDAs.
     */
    mapping(address => PlayerInfo) public playerData;

    // --- Events ---

    event DepositEvent(address indexed player, uint256 amount);
    event ApyRateUpdated(uint64 newRate);

    /**
     * @notice Emitted when a player successfully claims rewards.
     * @param player The address of the player.
     * @param amount The HBAR (tinybar) amount claimed.
     */
    event ClaimRewardsEvent(address indexed player, uint256 amount);

    // --- Errors ---

    error AmountMustBeGreaterThanZero();
    error NotAuthorized();
    error InvalidRewardTime();
    error InsufficientRewardPool();
    error TransferFailed();

    // --- Modifier ---

    modifier onlyAuthority() {
        if (msg.sender != authority) {
            revert NotAuthorized();
        }
        _;
    }

    // --- Constructor ---

    constructor(uint64 _apyRate) {
        authority = msg.sender;
        apyRate = _apyRate;
    }

    // --- Admin Functions ---

    function setApyRate(uint64 _newApyRate) public onlyAuthority {
        apyRate = _newApyRate;
        emit ApyRateUpdated(_newApyRate);
    }

    /**
     * @notice This is the conversion of your 'deposit' function.
     * It allows the authority to fund the reward pool.
     */
    function fundRewardPool() public payable onlyAuthority {
        if (msg.value == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        // This is 'vault_data.staked_amount += amount;'
        rewardPool += msg.value;
        
        // The transfer is implicit, as the HBAR is sent with the transaction.
        emit DepositEvent(msg.sender, msg.value);
    }

    // --- Player Functions ---

    /**
     * @notice Allows a player to claim their accrued rewards.
     * This is the conversion of your 'claim_rewards' function.
     */
    function claimRewards() public {
        // Load player data from the mapping.
        // 'storage' means we are modifying the data in-place.
        // This is 'let player_data = ctx.accounts.player_data.borrow_mut();'
        PlayerInfo storage player = playerData[msg.sender];

        // 'if player_data.staked_amount == 0'
        if (player.stakedAmount == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        // 'let current_time:u64 = Clock::get()...'
        uint64 currentTime = uint64(block.timestamp);

        // 'let time = current_time - player_data.reward_time;'
        uint64 timeElapsed = currentTime - player.rewardTime;

        // 'if time <= 0'
        if (timeElapsed == 0) {
            revert InvalidRewardTime();
        }

        // 'let rewards = player_data.staked_amount * game_data.apy_rate * time / 31_536_000;'
        // NOTE: We use 31,536,000 (seconds in a year) as the divisor.
        uint256 rewards = (player.stakedAmount * apyRate * timeElapsed) / 31_536_000;

        if (rewards == 0) {
            // No rewards to claim, but we'll reset the timer to prevent tiny dust txs
            player.rewardTime = currentTime;
            return;
        }

        // Check if the contract has enough HBAR to pay.
        // This checks 'game_data.staked_amount' (the rewardPool)
        if (rewardPool < rewards) {
            revert InsufficientRewardPool();
        }

        // Update accounting
        // 'game_data.staked_amount -= rewards;'
        rewardPool -= rewards;
        // 'player_data.reward_time = current_time;'
        player.rewardTime = currentTime;
        // 'player_data.reward_amount += rewards;'
        player.rewardAmount += rewards;

        // 'Transfer SOL to player'
        // This is 'transfer_lamports_from_owned_pda(...)'
        (bool success, ) = msg.sender.call{value: rewards}("");
        if (!success) {
            revert TransferFailed();
        }

        // 'emit!(ClaimRewardsEvent { ... })'
        emit ClaimRewardsEvent(msg.sender, rewards);
    }

    /**
     * !!! --- NOTE: This function is MISSING from your Rust code --- !!!
     * You need a way for players to stake. I have added an example
     * of what this 'stake' function might look like.
     * This function would set the 'player.stakedAmount' that
     * 'claimRewards' depends on.
     */
    function stake() public payable {
        if (msg.value == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        PlayerInfo storage player = playerData[msg.sender];
        
        // If player already has a stake, claim their pending rewards first.
        if (player.stakedAmount > 0) {
            claimRewards();
        }

        // Add new stake and set reward time
        player.stakedAmount += msg.value;
        player.rewardTime = uint64(block.timestamp);
        
        // This HBAR is now held by the contract, but it is *not*
        // added to the 'rewardPool'. It is an accounting liability.
    }
}