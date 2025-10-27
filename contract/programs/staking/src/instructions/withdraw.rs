use std::borrow::BorrowMut;
use anchor_lang::prelude::*;

use crate::{helpers::*, state::*};

pub fn withdraw(ctx: Context<Withdraw>) -> Result<()> {
    // Grab data from accounts
    let vault_balance = ctx.accounts.vault_data.get_lamports();
    let vault_data = ctx.accounts.vault_data.borrow_mut();

    // Accounting
    vault_data.staked_amount = 0;

    // Transfer SOL to devs
    transfer_lamports_from_owned_pda(&ctx.accounts.vault_data.to_account_info(), &ctx.accounts.authority.to_account_info(), vault_balance)?;

    msg!("The admin withdraw balance is {}", vault_balance);

    emit!(WithdrawEvent {
        amount: vault_balance,
    });

    Ok(())
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    authority: Signer<'info>,

    #[account(mut, seeds = [VaultAccount::SEED, authority.key().as_ref()], bump)]
    vault_data: Account<'info, VaultAccount>,

    system_program: Program<'info, System>,
}


#[event]
struct WithdrawEvent {
    amount: u64,
}