# 📑 Freelance Escrow Smart Contract

A decentralized escrow system for freelancers and clients, enabling secure job postings, fund escrow, and trustless dispute resolution via staked arbitrators.

---

## 🌟 Project Features

This project implements a smart contract that manages freelance job agreements. Clients post jobs with escrowed funds, freelancers submit work, and disputes are resolved by staked arbitrators. Key features:

- **Job Lifecycle Management**: Post, accept, submit, and confirm jobs.
- **Dispute Resolution**: Multi-signature voting by arbitrators.
- **Security**: Reentrancy protection, access control, and safe ETH transfers.

## ⚙️ Installation

```bash
# 1. Clone this repo
git clone <your-repo-url>
cd EscrowProject

# 2. Install dependencies
npm install
```

---

## 🔐 Configuration

1. Create a `.env` file in the project root:

    ```ini
    # .env
    PRIVATE_KEY=<YOUR_TESTNET_ACCOUNT_PRIVATE_KEY>
    SEPOLIA_RPC_URL=<https://eth-sepolia.alchemy.com/v2/yourKey>
    ETHERSCAN_API_KEY=<yourEtherscanApiKey>  # optional, for verification
    ```

2. Ensure `.gitignore` contains:

    ```gitignore
    node_modules/
    cache/
    artifacts/
    .env
    ```

3. Your `hardhat.config.js` should look like this:

    ```js
    require("dotenv").config();
    require("@nomiclabs/hardhat-waffle");
    require("@nomiclabs/hardhat-ethers");
    require("@nomiclabs/hardhat-etherscan");

    module.exports = {
      defaultNetwork: "sepolia",
      solidity: "0.8.20",
      networks: {
        sepolia: {
          url: process.env.SEPOLIA_RPC_URL,
          accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
        },
      },
      etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY,
      }
    };
    ```

---

## 🎯 Compile & Test

```bash
# Clean previous artifacts and compile contracts
npx hardhat clean
npx hardhat compile

# Run the full test suite
npx hardhat test
```

---

## 🚀 Deployment

```bash
# Deploy to Sepolia
npx hardhat run scripts/deploy.js --network sepolia
```

_Save the printed contract address for the next steps._

---

## 🎬 Demo Script

Run a scripted end-to-end flow against your deployed contract on Sepolia:

```bash
npm run demo -- <DEPLOYED_ADDRESS>
```

This script will:
1. Post job 0 (escrow 1 ETH)
2. Accept, submit, and confirm completion of job 0
3. Post job 1 and raise a dispute
4. Stake and vote with three arbitrators
5. Resolve and distribute funds

---

## 🛠️ Local Development

For rapid iteration, use a local Hardhat network:

1. In terminal #1, start node:
   ```bash
   npx hardhat node
   ```
2. In terminal #2, deploy to localhost:
   ```bash
   npx hardhat run scripts/deploy.js --network localhost
   ```
3. Copy the printed local address and run the demo:
   ```bash
   HARDHAT_NETWORK=localhost node scripts/demo.js <LOCAL_ADDRESS>
   ```

---

## 🔍 Verification

Once deployed, verify on Etherscan (requires `ETHERSCAN_API_KEY`):

You need to input your own Etherscan_API_Key in the .env file

```bash
npx hardhat verify \
  --network sepolia \
<Contract_Address>
```

_If your constructor takes arguments, list them after the address._

---

## 👤 Contributors & License

**Author:** Aidana Medetova  
**Email:** aidanam@connect.hku.hk

© 2025 The University of Hong Kong  



