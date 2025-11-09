# Staking Platform

A modern Next.js-based frontend for a Hedera staking platform that allows users to stake HBR tokens and earn rewards. Built with Next.js 13+, TypeScript, and Hedera Web3.js.

## Features

- 🔐 Secure wallet connection using Hedera Wallet Adapter
- 💰 HBR token staking with multiple duration options
- 📊 Real-time balance and staking information
- 🎯 Admin dashboard for platform management
- 🎨 Modern UI with dark theme
- 📱 Fully responsive design
- 🔄 Real-time transaction updates
- 🎯 Toast notifications for transaction status

## Features in Detail

### Staking
- Multiple staking duration options (7, 14, 30, 90 days)
- Real-time balance updates
- Transaction confirmation notifications
- APY display

### Admin Dashboard
- Platform statistics
- User management
- Transaction monitoring
- System configuration

### Security
- Secure wallet connection
- Transaction validation
- Error handling
- Protected admin routes

## Getting Started
1. Clone the repository:

```
git clone <repository-url>
cd staking-new-frontend
```

2. Install dependencies:
```
npm install
# or
yarn install
```

3. Create a .env.local file in the root directory and add your environment variables:

```
NEXT_PUBLIC_RPC_URL=<your-hedera-rpc-url>
```

4. Run the development server:
```
npm run dev
# or
yarn dev
```

5. Open `http://localhost:3000` with your browser to see the result.
