// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vault
 * @notice This contract holds staking data and configuration.
 * It now includes a 'deposit' function for native HBAR.
 */
contract Vault {

    // --- State Variables ---

    address public authority;
    uint64 public apyRate;
    uint256 public stakedAmount;

    // --- Events ---

    /**
     * @notice Emitted when a user deposits native currency (HBAR).
     * @param player The address of the user who deposited.
     * @param amount The amount of tinybars deposited.
     */
    event DepositEvent(address indexed player, uint256 amount);

    // --- Errors ---

    /**
     * @notice Replaces StakingError::AmountMustBeGreaterThanZero
     */
    error AmountMustBeGreaterThanZero();


    // --- Constructor ---

    constructor(uint64 _apyRate) {
        authority = msg.sender;
        apyRate = _apyRate;
        stakedAmount = 0;
    }

    // --- Functions ---

    /**
     * @notice Allows a user to deposit native HBAR into the vault.
     * This function replaces the 'deposit' function from the Rust code.
     * It is marked 'payable' to accept HBAR.
     */
    function deposit() public payable {
        
        // This 'msg.value' is the amount of HBAR (in tinybars) sent 
        // with the transaction. It replaces the 'amount: u64' parameter.
        if (msg.value == 0) {
            // Replaces 'return Err(StakingError::AmountMustBeGreaterThanZero.into())'
            revert AmountMustBeGreaterThanZero();
        }

        // 'msg.sender' is the equivalent of 'ctx.accounts.player.key()'
        address player = msg.sender;

        // 'stakedAmount' is a state variable of this contract.
        // This replaces 'vault_data.staked_amount += amount;'
        stakedAmount += msg.value;

        // NOTE: The 'transfer_lamports' call is handled automatically.
        // Because this function is 'payable', the HBAR (msg.value) sent by
        // the 'player' (msg.sender) is automatically and securely
        // transferred to this contract's address.

        // Replaces 'emit!(DepositEvent { ... })' and 'msg!(...)'
        emit DepositEvent(player, msg.value);

        // 'Ok(())' is implicit on successful function completion.
    }
}