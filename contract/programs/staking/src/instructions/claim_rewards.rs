use std::borrow::BorrowMut;
use anchor_lang::prelude::*;

use crate::{helpers::*, state::*, error::*};

pub fn claim_rewards(ctx: Context<ClaimRewards>) -> Result<()> {
    // Grab data from accounts
    let game_data = ctx.accounts.game_data.borrow_mut();
    let player_data = ctx.accounts.player_data.borrow_mut();

    if player_data.staked_amount == 0 {
        return Err(StakingError::AmountMustBeGreaterThanZero.into());
    }

    let current_time:u64 = Clock::get().unwrap().unix_timestamp.try_into().unwrap();

    let time = current_time - player_data.reward_time;
    if time <= 0 {
        return Err(StakingError::InvalidRewardTime.into());
    }
    
    // Calculate rewards
    let rewards = player_data.staked_amount * game_data.apy_rate * time / 31_536_000;

    // Update accounting
    game_data.staked_amount -= rewards;
    player_data.reward_time = current_time;
    player_data.reward_amount += rewards;

    msg!("The reward amount is {}", rewards);

    // Transfer SOL to player
    transfer_lamports_from_owned_pda(&ctx.accounts.game_data.to_account_info(), &ctx.accounts.player, rewards)?;

    emit!(ClaimRewardsEvent {
        player: ctx.accounts.player.key(),
        amount: rewards,
    });

    Ok(())
}

#[derive(Accounts)]
pub struct ClaimRewards<'info> {
    #[account(mut)]
    player: Signer<'info>,

    /// CHECK: Address constraint in account trait
    #[account(address = game_data.authority)]
    authority: UncheckedAccount<'info>,

    #[account(mut, seeds = [VaultAccount::SEED, authority.key().as_ref()], bump)]
    game_data: Account<'info, VaultAccount>,

    #[account(
        mut,
        seeds = [PlayerAccount::SEED, authority.key().as_ref(), player.key().as_ref()], 
        bump 
    )]
    player_data: Account<'info, PlayerAccount>,

    system_program: Program<'info, System>,
}


#[event]
struct ClaimRewardsEvent {
    player: Pubkey,
    amount: u64,
}