# LiteDEX 🚀

LiteDEX is a simple Automated Market Maker (AMM) Decentralized Exchange built with Solidity and Next.js. It implements the constant product formula ($x * y = k$) and allows users to swap tokens, add liquidity, and earn fees.

##  Project Structure

- `/contracts`: Smart contracts (DEX, Factory, Mock Tokens).
- `/frontend`: Next.js web application.
- `/scripts`: Hardhat deployment scripts.
- `/test`: Automated test suite for smart contracts.

##  Smart Contracts

- **SimpleDEX.sol**: The core AMM contract handling swaps (0.3% fee) and liquidity provision.
- **DEXFactory.sol**: Factory contract to deploy and track multiple trading pairs.
- **MockERC20.sol**: Sample tokens for testing.

##  Getting Started (Contracts)

### 1. Install Dependencies
```bash
npm install
```

### 2. Compile Contracts
```bash
npx hardhat compile
```

### 3. Run Tests
```bash
npx hardhat test
```

### 4. Deploy Locally
First, start a local Hardhat node:
```bash
npx hardhat node
```
Then deploy the contracts:
```bash
npx hardhat run scripts/deploy.js --network localhost
```

##  Security Features
- **ReentrancyGuard**: Protects against recursive call attacks.
- **Price Oracle (TWAP)**: Industry-standard time-weighted average price tracking.
- **K-Invariant Check**: Ensures pool mathematical stability after every swap.
