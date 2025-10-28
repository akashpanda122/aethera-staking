// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vault
 * @notice This contract holds staking data and configuration.
 * It now includes an admin-only 'setApyRate' function.
 */
contract Vault {

    // --- State Variables ---

    address public authority;
    uint64 public apyRate;
    uint256 public stakedAmount;

    // --- Events ---

    event DepositEvent(address indexed player, uint256 amount);
    
    /**
     * @notice Emitted when the authority updates the APY rate.
     * @param newRate The new APY rate.
     */
    event ApyRateUpdated(uint64 newRate);

    // --- Errors ---

    error AmountMustBeGreaterThanZero();

    /**
     * @notice Replaces the authority constraint check.
     */
    error NotAuthorized();

    // --- Modifier ---

    /**
     * @notice Ensures that only the contract's authority can call a function.
     * This modifier replaces the 'authority: Signer' constraint in Anchor.
     */
    modifier onlyAuthority() {
        // 'msg.sender' is the caller of the function.
        // 'authority' is the address we stored in the constructor.
        if (msg.sender != authority) {
            revert NotAuthorized();
        }
        _; // This proceeds with the rest of the function's execution.
    }

    // --- Constructor ---

    constructor(uint64 _apyRate) {
        authority = msg.sender;
        apyRate = _apyRate;
        stakedAmount = 0;
    }

    // --- Functions ---

    function deposit() public payable {
        if (msg.value == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        
        stakedAmount += msg.value;
        emit DepositEvent(msg.sender, msg.value);
    }

    /**
     * @notice Updates the APY rate for the vault.
     * This is the Solidity equivalent of your 'config' function.
     * @param _newApyRate The new APY rate to set.
     */
    function setApyRate(uint64 _newApyRate) public onlyAuthority {
        // The 'onlyAuthority' modifier automatically performs the
        // authority check for us.

        // This replaces 'let vault_data = ...; vault_data.apy_rate = apy_rate;'
        apyRate = _newApyRate;

        // This replaces 'msg!("The admin apy config is {}", apy_rate);'
        emit ApyRateUpdated(_newApyRate);

        // 'Ok(())' is implicit on successful completion.
    }
}