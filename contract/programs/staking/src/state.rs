use anchor_lang::{prelude::*, solana_program::clock::Slot};

#[account]
pub struct VaultAccount {
    pub authority: Pubkey,
    pub staked_amount: u64,
    pub apy_rate: u64,
}

impl VaultAccount {
    pub const SPACE: usize = 32 + 16 + 8 + 8;
    pub const SEED: &'static [u8] = b"vault"; 
}

#[account]
pub struct PlayerAccount {
    pub staked_time: u64,
    pub staked_amount: u64,
    pub reward_time: u64,
    pub duration_time: u64,
    pub reward_amount: u64,
}

impl PlayerAccount {
    pub const SPACE: usize = 16 + 16 + 8;
    pub const SEED: &'static [u8] = b"player"; 
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct TokenDetails {
    pub name: String,
    pub symbol: String,
    pub uri: String,
    pub initial_supply: u64,
}