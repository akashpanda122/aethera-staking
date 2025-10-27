use std::borrow::BorrowMut;

use anchor_lang::prelude::*;
use anchor_spl::{associated_token::AssociatedToken, token::{Mint, Token, TokenAccount}};

use crate::{state::*};

pub fn initialize(ctx: Context<Initialize>, apy_rate: u64) -> Result<()> {
    let vault_data = ctx.accounts.vault_data.borrow_mut();

    // Set defaults
    vault_data.staked_amount = 0;
    vault_data.apy_rate = apy_rate;
    vault_data.authority = ctx.accounts.authority.key();

    Ok(())
}


#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(mut)]
    authority: Signer<'info>,

    #[account(
        init, 
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