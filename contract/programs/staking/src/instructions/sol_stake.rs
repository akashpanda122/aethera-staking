use std::borrow::BorrowMut;
use anchor_spl::{associated_token::AssociatedToken, token::{Mint, Token, TokenAccount}, token_interface::{mint_to, MintTo}};
use anchor_lang::{prelude::*, solana_program::sysvar::{self}};

use crate::{error::*, helpers::*, state::*};

pub fn sol_stake(ctx: Context<SolStake>, amount: u64, duration: u64) -> Result<()> {    

    if amount == 0 {
        return Err(StakingError::AmountMustBeGreaterThanZero.into());
    }

    let player_key = ctx.accounts.player.key();

    let vault_data = ctx.accounts.vault_data.borrow_mut();
    let player_data = ctx.accounts.player_data.borrow_mut();

    let current_time:u64 = Clock::get().unwrap().unix_timestamp.try_into().unwrap();

    player_data.staked_amount += amount;
    player_data.staked_time = current_time;
    player_data.duration_time = duration;
    player_data.reward_time = current_time;

    vault_data.staked_amount += amount;

    msg!("The stake amount is {}", amount);
    msg!("The duration is {}", duration);

    // Transfer SOL to vault account
    transfer_lamports(&ctx.accounts.player, &ctx.accounts.vault_data.to_account_info(), &ctx.accounts.system_program, amount)?;

    emit!(SolStakeEvent {
        player: player_key,
        amount: amount,
        duration: duration,
    });

    Ok(())
}

#[derive(Accounts)]
pub struct SolStake<'info> {
    #[account(mut)]
    player: Signer<'info>,

    /// CHECK: Address constraint in account trait
    #[account(address = vault_data.authority)]
    authority: UncheckedAccount<'info>,

    #[account(mut, seeds = [VaultAccount::SEED, authority.key().as_ref()], bump)]
    vault_data: Account<'info, VaultAccount>,

    #[account(
        init_if_needed, 
        seeds = [PlayerAccount::SEED, authority.key().as_ref(), player.key().as_ref()], 
        bump, 
        payer = player, 
        space = 8 + PlayerAccount::SPACE
    )]
    player_data: Account<'info, PlayerAccount>,

    token_program: Program<'info, Token>,
    associated_token_program: Program<'info, AssociatedToken>,

    /// CHECK: Address constraint in account trait
    #[account(address = sysvar::instructions::id())]
    instructions: UncheckedAccount<'info>,

    system_program: Program<'info, System>,
}

#[event]
struct SolStakeEvent {
    player: Pubkey,
    amount: u64,
    duration: u64,
}
