use std::borrow::BorrowMut;
use anchor_lang::prelude::*;

use crate::{helpers::*, state::*, error::*};

pub fn sol_unstake(ctx: Context<SolUnstake>) -> Result<()> {
    // Grab data from accounts
    let vault_data = ctx.accounts.vault_data.borrow_mut();
    let player_data = ctx.accounts.player_data.borrow_mut();

    let current_time:u64 = Clock::get().unwrap().unix_timestamp.try_into().unwrap();
    let expired = player_data.staked_time + player_data.duration_time;

    if expired > current_time {
        return Err(StakingError::InvalidUnstakeTime.into());
    }

    let amount = player_data.staked_amount;

    msg!("The unstake amount is {}", amount);

    // Update accounting
    vault_data.staked_amount -= amount;
    player_data.staked_amount = 0;

    // Transfer SOL to player
    transfer_lamports_from_owned_pda(&ctx.accounts.vault_data.to_account_info(), &ctx.accounts.player, amount)?;

    emit!(SolUnstakeEvent {
        player: ctx.accounts.player.key(),
        amount: amount,
    });

    Ok(())
}

#[derive(Accounts)]
pub struct SolUnstake<'info> {
    #[account(mut)]
    player: Signer<'info>,

    /// CHECK: Address constraint in account trait
    #[account(address = vault_data.authority)]
    authority: UncheckedAccount<'info>,

    #[account(mut, seeds = [VaultAccount::SEED, authority.key().as_ref()], bump)]
    vault_data: Account<'info, VaultAccount>,

    #[account(
        mut,
        seeds = [PlayerAccount::SEED, authority.key().as_ref(), player.key().as_ref()], 
        bump 
    )]
    player_data: Account<'info, PlayerAccount>,

    system_program: Program<'info, System>,
}


#[event]
struct SolUnstakeEvent {
    player: Pubkey,
    amount: u64,
}