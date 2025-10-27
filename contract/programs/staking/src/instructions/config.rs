use std::borrow::BorrowMut;

use anchor_lang::prelude::*;
use anchor_spl::{associated_token::AssociatedToken, token::{Mint, Token, TokenAccount}};

use crate::{state::*};

pub fn config(ctx: Context<Config>, apy_rate: u64) -> Result<()> {
    let vault_data = ctx.accounts.vault_data.borrow_mut();

    // Set defaults
    vault_data.apy_rate = apy_rate;

    msg!("The admin apy config is {}", apy_rate);

    Ok(())
}


#[derive(Accounts)]
pub struct Config<'info> {
    #[account(mut)]
    authority: Signer<'info>,

    #[account(
        init_if_needed, 
        seeds = [VaultAccount::SEED, authority.key().as_ref()], 
        bump, 
        payer = authority, 
        space = 8 + VaultAccount::SPACE
    )]
    vault_data: Account<'info, VaultAccount>,
    
    token_program: Program<'info, Token>,
    associated_token_program: Program<'info, AssociatedToken>,

    system_program: Program<'info, System>,
}