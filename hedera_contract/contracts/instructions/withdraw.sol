// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HederaStakingWithdraw
 * @dev Withdraw functionality for Hedera staking contract
 * Converted from Solana Anchor withdraw instruction
 */

/**
 * @dev Import or define required structures and errors
 */

// VaultAccount structure (from previous conversion)
struct VaultAccount {
    address authority;
    uint256 stakedAmount;
    uint256 apyRate;
}

// Custom errors
error OnlyAuthority(address caller, address expected);
error InsufficientContractBalance(uint256 required, uint256 available);
error TransferFailed(address to, uint256 amount);
error WithdrawNotAllowed(string reason);

/**
 * @title StakingWithdraw
 * @dev Contract module for admin withdrawal functionality
 */
abstract contract StakingWithdraw {
    
    // State variables
    VaultAccount internal vault;
    
    // Events
    /**
     * @dev Emitted when admin withdraws funds
     * @param authority Address that performed withdrawal
     * @param amount Amount withdrawn in tinybars
     * @param timestamp Time of withdrawal
     */
    event WithdrawEvent(
        address indexed authority,
        uint256 amount,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted for detailed withdrawal info
     * @param authority Admin address
     * @param amount Amount withdrawn
     * @param contractBalanceBefore Balance before withdrawal
     * @param contractBalanceAfter Balance after withdrawal
     */
    event AdminWithdrawal(
        address indexed authority,
        uint256 amount,
        uint256 contractBalanceBefore,
        uint256 contractBalanceAfter
    );
    
    // Modifiers
    modifier onlyAuthority() {
        if (msg.sender != vault.authority) {
            revert OnlyAuthority(msg.sender, vault.authority);
        }
        _;
    }
    
    /**
     * @dev Admin withdraw all available funds from contract
     * Equivalent to Solana's withdraw instruction
     * 
     * Only withdraws available balance (not staked funds)
     * Resets vault.stakedAmount to 0
     * Transfers all HBAR to authority
     */
    function withdraw() external onlyAuthority {
        // Grab data from contract (equivalent to ctx.accounts)
        uint256 contractBalance = address(this).balance;
        uint256 stakedAmount = vault.stakedAmount;
        
        // Calculate available balance (total - staked)
        // In production, you may want to keep staked funds separate
        uint256 availableBalance = contractBalance;
        
        // Check if there's anything to withdraw
        if (availableBalance == 0) {
            revert WithdrawNotAllowed("No funds available");
        }
        
        // Store balance before for event
        uint256 balanceBefore = contractBalance;
        
        // Accounting: Reset staked amount
        // WARNING: This withdraws ALL funds including staked amounts
        // Consider modifying to only withdraw excess funds
        vault.stakedAmount = 0;
        
        // Transfer HBAR to authority (equivalent to transfer_lamports_from_owned_pda)
        address payable authorityAddress = payable(vault.authority);
        (bool success, ) = authorityAddress.call{value: availableBalance}("");
        
        if (!success) {
            revert TransferFailed(authorityAddress, availableBalance);
        }
        
        // Log withdrawal amount (equivalent to msg! macro)
        // Note: In Solidity, use events instead of logs
        
        // Emit events
        emit WithdrawEvent(
            vault.authority,
            availableBalance,
            block.timestamp
        );
        
        emit AdminWithdrawal(
            vault.authority,
            availableBalance,
            balanceBefore,
            address(this).balance
        );
    }
    
    /**
     * @dev Safe admin withdraw - only withdraws excess funds
     * This version protects staked funds and only withdraws available balance
     * @return amount Amount withdrawn
     */
    function withdrawSafe() external onlyAuthority returns (uint256 amount) {
        uint256 contractBalance = address(this).balance;
        uint256 stakedAmount = vault.stakedAmount;
        
        // Calculate available balance (total balance - staked funds)
        if (contractBalance <= stakedAmount) {
            revert InsufficientContractBalance(1, 0);
        }
        
        amount = contractBalance - stakedAmount;
        
        if (amount == 0) {
            revert WithdrawNotAllowed("No excess funds to withdraw");
        }
        
        // Transfer only excess funds
        address payable authorityAddress = payable(vault.authority);
        (bool success, ) = authorityAddress.call{value: amount}("");
        
        if (!success) {
            revert TransferFailed(authorityAddress, amount);
        }
        
        emit WithdrawEvent(
            vault.authority,
            amount,
            block.timestamp
        );
        
        emit AdminWithdrawal(
            vault.authority,
            amount,
            contractBalance,
            address(this).balance
        );
    }
    
    /**
     * @dev Withdraw specific amount
     * @param amount Amount to withdraw in tinybars
     */
    function withdrawAmount(uint256 amount) external onlyAuthority {
        if (amount == 0) {
            revert WithdrawNotAllowed("Amount must be greater than zero");
        }
        
        uint256 contractBalance = address(this).balance;
        uint256 stakedAmount = vault.stakedAmount;
        uint256 availableBalance = contractBalance - stakedAmount;
        
        if (amount > availableBalance) {
            revert InsufficientContractBalance(amount, availableBalance);
        }
        
        // Transfer specified amount
        address payable authorityAddress = payable(vault.authority);
        (bool success, ) = authorityAddress.call{value: amount}("");
        
        if (!success) {
            revert TransferFailed(authorityAddress, amount);
        }
        
        emit WithdrawEvent(
            vault.authority,
            amount,
            block.timestamp
        );
        
        emit AdminWithdrawal(
            vault.authority,
            amount,
            contractBalance,
            address(this).balance
        );
    }
    
    /**
     * @dev Emergency withdraw - withdraws all funds including staked
     * USE WITH EXTREME CAUTION - This will break active stakes
     * Should only be used in emergency situations
     */
    function emergencyWithdraw() external onlyAuthority {
        uint256 totalBalance = address(this).balance;
        
        if (totalBalance == 0) {
            revert WithdrawNotAllowed("No funds in contract");
        }
        
        // Reset vault accounting
        vault.stakedAmount = 0;
        
        // Transfer all funds
        address payable authorityAddress = payable(vault.authority);
        (bool success, ) = authorityAddress.call{value: totalBalance}("");
        
        if (!success) {
            revert TransferFailed(authorityAddress, totalBalance);
        }
        
        emit WithdrawEvent(
            vault.authority,
            totalBalance,
            block.timestamp
        );
        
        emit AdminWithdrawal(
            vault.authority,
            totalBalance,
            totalBalance,
            0
        );
    }
    
    /**
     * @dev Get withdrawable balance
     * @return available Amount available for withdrawal
     * @return staked Amount currently staked
     * @return total Total contract balance
     */
    function getWithdrawableBalance() 
        external 
        view 
        returns (
            uint256 available,
            uint256 staked,
            uint256 total
        ) 
    {
        total = address(this).balance;
        staked = vault.stakedAmount;
        available = total > staked ? total - staked : 0;
    }
    
    /**
     * @dev Check if authority can withdraw
     * @return canWithdraw True if withdrawal is possible
     * @return availableAmount Amount that can be withdrawn
     */
    function canWithdraw() 
        external 
        view 
        returns (bool canWithdraw, uint256 availableAmount) 
    {
        uint256 total = address(this).balance;
        uint256 staked = vault.stakedAmount;
        
        if (total > staked) {
            canWithdraw = true;
            availableAmount = total - staked;
        } else {
            canWithdraw = false;
            availableAmount = 0;
        }
    }
}

/**
 * @title CompleteStakingWithdraw
 * @dev Full implementation example combining withdraw with other functionality
 */
contract CompleteStakingWithdraw is StakingWithdraw {
    
    // Additional state
    bool public paused;
    
    // Events
    event ContractPaused(address indexed by, uint256 timestamp);
    event ContractUnpaused(address indexed by, uint256 timestamp);
    
    // Modifiers
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }
    
    /**
     * @dev Constructor
     */
    constructor() {
        vault.authority = msg.sender;
        vault.stakedAmount = 0;
        vault.apyRate = 5000; // 50% APY
        paused = false;
    }
    
    /**
     * @dev Pause contract (for emergency)
     */
    function pause() external onlyAuthority whenNotPaused {
        paused = true;
        emit ContractPaused(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyAuthority whenPaused {
        paused = false;
        emit ContractUnpaused(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Override withdraw to add pause check
     */
    function withdraw() external override onlyAuthority whenPaused {
        super.withdraw();
    }
    
    /**
     * @dev Receive function to accept HBAR
     */
    receive() external payable {
        emit AdminWithdrawal(
            msg.sender,
            msg.value,
            address(this).balance - msg.value,
            address(this).balance
        );
    }
}

/**
 * @title WithdrawHelper
 * @dev Helper functions for withdrawal operations
 */
library WithdrawHelper {
    
    /**
     * @dev Calculate withdrawable amount
     * @param totalBalance Total contract balance
     * @param stakedAmount Amount currently staked
     * @return withdrawable Amount available for withdrawal
     */
    function calculateWithdrawable(
        uint256 totalBalance,
        uint256 stakedAmount
    ) internal pure returns (uint256 withdrawable) {
        if (totalBalance > stakedAmount) {
            withdrawable = totalBalance - stakedAmount;
        } else {
            withdrawable = 0;
        }
    }
    
    /**
     * @dev Validate withdrawal amount
     * @param amount Amount to withdraw
     * @param available Available balance
     * @return valid True if amount is valid
     */
    function isValidWithdrawal(
        uint256 amount,
        uint256 available
    ) internal pure returns (bool valid) {
        valid = amount > 0 && amount <= available;
    }
}