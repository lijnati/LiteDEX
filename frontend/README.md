# LiteDEX Frontend 

The web interface for LiteDEX, built with **Next.js** and **ethers.js**.

##  Features
- **Modern UI**: Glassmorphism design with a sleek dark mode.
- **Wallet Connection**: Integrated with MetaMask.
- **Swap Interface**: Real-time price calculation and slippage protection.
- **Liquidity Pool**: Add assets to earn LP tokens and track your position.

##  Getting Started

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Addresses
The contract addresses are located in `src/app/constants.js`. If you redeploy your contracts to a local node, update these values:
```javascript
export const DEX_FACTORY_ADDRESS = "0x...";
export const TOKEN_A_ADDRESS = "0x...";
export const TOKEN_B_ADDRESS = "0x...";
```

### 3. Run Development Server
```bash
npm run dev
```
Visit [http://localhost:3000](http://localhost:3000) to see the app.

##  Stack
- **Framework**: Next.js (App Router)
- **Web3**: ethers.js (v6)
- **Styling**: Vanilla CSS (globals.css)
- **Icons**: Lucide React
- **Font**: Poppins (Google Fonts)
