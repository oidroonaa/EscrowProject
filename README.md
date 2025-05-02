# 📑 Freelance Escrow Smart Contract

A decentralized on-chain escrow system for freelancers and clients, enabling secure job postings, fund escrow, timeouts, and trustless dispute resolution via staked arbitrators.

---

## 🌟 Project Features

This project implements a smart contract that manages freelance job agreements. Clients post jobs with escrowed funds, freelancers submit work, and disputes are resolved by staked arbitrators.

- **Job Lifecycle**  
  - `postJob()` → escrow your ETH  
  - `acceptJob()` → freelancer locks in  
  - `submitWork()` → deliver off-chain proof  
  - `confirmCompletion()` / `autoConfirm()` → release funds  

- **Cancellation & Timeouts**  
  - `withdrawJob()` → client cancels before acceptance  
  - `cancelAfterAccept()` → client cancels after deadline if no submission  
  - `autoConfirm()` → freelancer completes if client forgets after `AUTO_COMPLETE_DELAY`  
  - `resolveOverdue()` → voters reclaim stakes if dispute stalls past `DISPUTE_WINDOW`

- **Staked Arbitration**  
  - `stake()` / `unstake()` → arbitrators lock ETH  
  - 1 h cooldown after staking before voting  
  - Cap of `MAX_VOTERS` per dispute

- **Evidence Submission**  
  - `submitEvidence(jobId, hash, uri)` → store 32-byte hash + off-chain URI  
  - Voters must see `evidenceHash` before `voteDispute()`

- **Dispute Resolution**  
  - `voteDispute()` → tally to `VOTE_THRESHOLD`  
  - Honest voters refunded + share of slashed stakes  
  - Winner receives escrow


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
    require("@nomicfoundation/hardhat-verify");
    
    module.exports = {
      defaultNetwork: "sepolia",
      solidity: {
        version: "0.8.20",
        settings: { optimizer: { enabled: true, runs: 200 } }
      },
      networks: {
        sepolia: {
          url: process.env.SEPOLIA_RPC_URL,
          accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
          gasPrice: 10_000_000_000
        },
        localhost: {
          url: "http://127.0.0.1:8545"
        }
      },
      etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY
      }
    };
    ```

---

## 🎯 Compile & Test

All tests should pass, including evidence-based dispute flows.

```bash
# Clean previous artifacts and compile contracts
npx hardhat clean
npx hardhat compile

# Run the full test suite
npx hardhat test
```

---

## 🚀 Deployment

1. Fund your account via a faucet(≥ 0.1 ETH).

2. Deploy to Sepolia
```bash
npx hardhat run scripts/deploy.js --network sepolia
```
3. Save the printed contracts address for verification & demo

---

## 🎬 Demo Script

Run a scripted end-to-end flow against your deployed contract on Sepolia:

```bash
npm run demo -- <DEPLOYED_ADDRESS>
```

This script will:
1. Job 0 – post, accept, submit, confirm
2. Job 1 – post, accept, submit, raise dispute
3. Evidence – submit on-chain hash+URI
4. Arbitration setup – grant roles & stake
5. Cooldown – fast-forward block timestamp by 1 hour
6. Voting – three arbitrators cast votes
7. Resolution – dispute automatically resolves when threshold is met

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

## References 

**IEEE S&P**
“Compositional Security for Reentrant Applications” (2021)
"SoK: Prudent Evaluation Practices for Fuzzing" (2024)

**NDSS**
“Security and Privacy for Blockchains” (2025 workshop)
"Security for Large-Scale Critical Infrastructures" (2025)

**USENIX Security**
“Not Yet Another Digital ID” (2023)

**Springer Surveys**
“Blockchain for Securing Electronic Voting” (2025)

## 👤 Contributors & License

**Author:** Aidana Medetova  
**Email:** aidanam@connect.hku.hk

© 2025 The University of Hong Kong  



