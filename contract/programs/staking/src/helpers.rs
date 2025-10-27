use anchor_lang::{prelude::*, solana_program::{clock::Slot, keccak, program_memory::sol_memcmp, pubkey::PUBKEY_BYTES}, system_program};
use arrayref::array_ref;

use crate::error::StakingError;

// Global constants for game
pub const FLOAT_SCALAR: u128 = u128::pow(2, 48); // 2**48

// Transfer lamports between accounts via CPI call to system program
pub fn transfer_lamports<'a>(
    from: &AccountInfo<'a>,
    to: &AccountInfo<'a>,
    system_program: &Program<'a, System>,
    lamports: u64,
) -> Result<()> {
    let cpi_accounts = system_program::Transfer {
        from: from.to_account_info(),
        to: to.to_account_info(),
    };
    let cpi_program = system_program.to_account_info();
    let cpi_context = CpiContext::new(cpi_program, cpi_accounts);
    system_program::transfer(cpi_context, lamports)?;
    Ok(())
}

// Transfer lamports from an owned PDA to another account
pub fn transfer_lamports_from_owned_pda<'a>(
    from: &AccountInfo<'a>,
    to: &AccountInfo<'a>,
    lamports: u64,
) -> Result<()> {

    **from.try_borrow_mut_lamports()? -= lamports;
    **to.try_borrow_mut_lamports()? += lamports;

    Ok(())
}

pub fn cmp_pubkeys(a: &Pubkey, b: &Pubkey) -> bool {
    sol_memcmp(a.as_ref(), b.as_ref(), PUBKEY_BYTES) == 0
}
