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
2. Install dependencies
`npm install`

### Usage

1. Compile Contracts
`npx hardhat compile`

2. Run Tests
`npx hardhat test`

3. Deploy Contract
`npx hardhat run scripts/deploy.js --network hardhat`
Save the deployed contract address (e.g., 0x5FbDB2315678afecb367f032d93F642f64180aa3)

### Demo Flow

1. Start a local Hardhat node:
`npx hardhat node`
2. In a new terminal, run the demo script with the deployed contract address:
`npx hardhat run scripts/demo.js --network localhost [CONTRACT_ADDRESS]`

Example:
`npx hardhat run scripts/demo.js --network localhost 0x5FbDB2315678afecb367f032d93F642f64180aa3`

### Contributing

Pull requests are welcome. For major changes, open an issue first.

### License

MIT
`This README provides a comprehensive guide to setup, test, and interact with the contract. The actual Solidity code is inferred from the tests and scripts but would need to be included in the repository for full functionality.`
