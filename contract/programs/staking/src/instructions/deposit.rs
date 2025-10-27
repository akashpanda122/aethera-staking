use std::borrow::BorrowMut;
use anchor_spl::{associated_token::AssociatedToken, token::{Mint, Token, TokenAccount}, token_interface::{mint_to, MintTo}};
use anchor_lang::{prelude::*, solana_program::sysvar::{self}};

use crate::{error::*, helpers::*, state::*};

pub fn deposit(ctx: Context<Deposit>, amount: u64) -> Result<()> {    

    if amount == 0 {
        return Err(StakingError::AmountMustBeGreaterThanZero.into());
    }

    let player_key = ctx.accounts.player.key();

    let vault_data = ctx.accounts.vault_data.borrow_mut();

    vault_data.staked_amount += amount;

    msg!("The admin deposit amount is {}", amount);

    // Transfer SOL to vault account
    transfer_lamports(&ctx.accounts.player, &ctx.accounts.vault_data.to_account_info(), &ctx.accounts.system_program, amount)?;

    emit!(DepositEvent {
        player: player_key,
        amount: amount,
    });

    Ok(())
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(mut)]
    player: Signer<'info>,

    /// CHECK: Address constraint in account trait
    #[account(address = vault_data.authority)]
    authority: UncheckedAccount<'info>,

    #[account(mut, seeds = [VaultAccount::SEED, authority.key().as_ref()], bump)]
    vault_data: Account<'info, VaultAccount>,

    token_program: Program<'info, Token>,
    associated_token_program: Program<'info, AssociatedToken>,

    /// CHECK: Address constraint in account trait
    #[account(address = sysvar::instructions::id())]
    instructions: UncheckedAccount<'info>,

    system_program: Program<'info, System>,
}

#[event]
struct DepositEvent {
    player: Pubkey,
    amount: u64,
}
