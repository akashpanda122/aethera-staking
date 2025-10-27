# Colosseum Staking Contract

A Solana-based staking contract built with Anchor framework.

## Overview

This project implements a staking contract on the Solana blockchain using the Anchor framework. The contract is deployed on Solana's devnet.

## Prerequisites

- Node.js (v16 or later)
- Rust and Cargo
- Solana CLI tools
- Anchor Framework

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd contract
```

2. Install dependencies:
```bash
yarn install
```

3. Build the program:
```bash
anchor build
```

## Development

The project uses the following main dependencies:
- @coral-xyz/anchor: ^0.30.1
- @solana/spl-token: ^0.4.8

### Project Structure

```
├── programs/           # Solana program source code
│   └── staking/       # Staking program
├── tests/             # Test files
├── Anchor.toml        # Anchor configuration
└── package.json       # Project dependencies
```

### Available Scripts

- `yarn lint`: Check code formatting
- `yarn lint:fix`: Fix code formatting issues
- `anchor test`: Run the test suite

## Testing

Tests are written in TypeScript using Mocha and Chai. Run the tests with:

```bash
anchor test
```

## Deployment

The contract is configured to deploy on Solana's devnet. The program ID is:
```
staking = "Djo4ajv8rFv4i8Bt27BEtsUA5G3ToKBC5b2JKeF7i2nw"
```

## License

ISC
