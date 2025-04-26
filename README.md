# Freelance Escrow Smart Contract

A decentralized escrow system for freelancers and clients, enabling secure transactions with dispute resolution via arbitrators.

## Project Overview

This project implements a smart contract that manages freelance job agreements. Clients post jobs with escrowed funds, freelancers submit work, and disputes are resolved by staked arbitrators. Key features:

- **Job Lifecycle Management**: Post, accept, submit, and confirm jobs.
- **Dispute Resolution**: Multi-signature voting by arbitrators.
- **Security**: Reentrancy protection, access control, and safe ETH transfers.

## Project Setup

### Installation

1. Clone the repository
`cd EscrowProject`
3. Install dependencies
`npm install`

### Configuration

1. Create a .env file in the project root
`# .env
PRIVATE_KEY=<your_testnet_account_private_key>
SEPOLIA_RPC_URL=<https://eth-sepolia.alchemy.com/v2/yourKey>
ETHERSCAN_API_KEY=<yourEtherscanApiKey>  # optional, for verification`
2. Hardhat configuration
`require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");

module.exports = {
  solidity: "0.8.20",
  defaultNetwork: "sepolia",
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};`


### Usage

1. Compile Contracts


`npx hardhat clean
npx hardhat compile`

3. Run Tests
`npx hardhat test`

4. Deploy Contract
`npx hardhat run scripts/deploy.js --network sepolia`
Save the deployed address from the console.

5. Verify on Etherscan (requires ETHERSCAN_API_KEY):
`npx hardhat verify --network sepolia <DEPLOYED_ADDRESS>`
If your constructor had arguments, list them after the address.

### Demo Script

1. Interact with the deployed contract end‑to‑end on a testnet:
`npm run demo -- <DEPLOYED_ADDRESS>`

This will:
1. Post a job
2. Accept, submit, and confirm completion of job 0
3. Post + dispute job 1
4. Arbitrator staking & votes
5. Show dispute resolution

#### Local Development

1. Start a local network in one terminal:
`npx hardhat node`
2. Deploy your contracts locally
`npx hardhat run scripts/deploy.js --network localhost`
Copy the printed address
4. In a new terminal, run the demo script against localhost with the deployed contract address:
`npx hardhat run scripts/demo.js --network localhost [CONTRACT_ADDRESS]`

### Contributors

Author: Aidana Medetova
Email: aidanam@connect.hku.hk

### License

2025 © The University of Hong Kong
