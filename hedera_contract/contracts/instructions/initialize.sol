// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vault
 * @notice This contract holds staking data and configuration.
 * It is the Solidity equivalent of the provided Anchor 'VaultAccount' state.
 */
contract Vault {

    // --- State Variables ---
    // These replace the fields in the 'VaultAccount' struct in Rust.

    /**
     * @notice The address of the authority (admin) of this vault.
     * Equivalent to 'authority: Pubkey'
     */
    address public authority;

    /**
     * @notice The APY rate for staking, stored as a simple integer.
     * Equivalent to 'apy_rate: u64'
     */
    uint64 public apyRate;

    /**
     * @notice The total amount of tokens staked in this vault.
     * Equivalent to 'staked_amount: u64'.
     * We use uint256 as it's the standard for token amounts in the EVM
     * (and for HTS/ERC-20 tokens).
     */
    uint256 public stakedAmount;

    // --- Constructor ---
    // This 'constructor' function replaces the 'initialize' function in Rust.
    // It is executed only ONCE, when the contract is first deployed.

    /**
     * @param _apyRate The initial APY rate to set for the vault.
     */
    constructor(uint64 _apyRate) {
        // 'msg.sender' is the address that deploys the contract.
        // This is the equivalent of 'ctx.accounts.authority.key()'
        authority = msg.sender;

        // Set the APY rate from the deployment parameter.
        apyRate = _apyRate;

        // 'stakedAmount' is automatically initialized to 0 by default,
        // but we can set it explicitly to match the Rust code.
        stakedAmount = 0;
    }
}