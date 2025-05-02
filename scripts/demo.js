require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  // Read your deployed address from the first CLI arg:
  const escrowAddress = process.argv[2];
  if (!escrowAddress) {
    console.error(
      "Usage: HARDHAT_NETWORK=<network> node scripts/demo.js <ESCROW_ADDRESS>"
    );
    process.exit(1);
  }

  // 1) Get your signers
  const [deployer, client, freelancer, arb1, arb2, arb3] = await ethers.getSigners();

  // 2) Attach to the already‐deployed contract
  const escrow = await ethers.getContractAt("FreelanceEscrow", escrowAddress);

  // 3) Happy path
  console.log("✍️  Posting job...");
  await escrow.connect(client).postJob({ value: ethers.utils.parseEther("1") });
  console.log("✅ Job 0 posted");

  console.log("🤝 Accepting job 0...");
  await escrow.connect(freelancer).acceptJob(0);

  console.log("📤 Submitting work for job 0...");
  await escrow.connect(freelancer).submitWork(0);

  console.log("✔️  Confirming completion for job 0...");
  await escrow.connect(client).confirmCompletion(0);

  // 4) Dispute path
  console.log("\n🔨 Posting & raising dispute on job 1...");
  await escrow.connect(client).postJob({ value: ethers.utils.parseEther("1") });
  await escrow.connect(freelancer).acceptJob(1);
  await escrow.connect(freelancer).submitWork(1);
  await escrow.connect(client).raiseDispute(1);

  console.log(" 📝 Submitting evidence for job 1...");
  const evidenceHash = ethers.utils.id("demo-evidence");
  const evidenceURI = "ipfs://QmDemoCid";
  await escrow.connect(client).submitEvidence(1, evidenceHash, evidenceURI);


  console.log("🤝🏻 Granting ARBITRATOR_ROLE to arb1, arb2, arb3...");
  await escrow
    .connect(deployer)
    .grantArbitratorRole(arb1.address);
  await escrow
    .connect(deployer)
    .grantArbitratorRole(arb2.address);
  await escrow
    .connect(deployer)
    .grantArbitratorRole(arb3.address);

  console.log("⚡ Staking 1 ETH for each arbitrator...");
  for (const arb of [arb1, arb2, arb3]) {
    await escrow
      .connect(arb)
      .stake({ value: ethers.utils.parseEther("1")});
  }

  console.log("🗳️ Fast-forwarding 1 hour so they can vote...");
  await ethers.provider.send("evm_increaseTime", [3600]);
  await ethers.provider.send("evm_mine");

  console.log("📢 Arbitrator voting");
  await escrow.connect(arb1).voteDispute(1, true);
  await escrow.connect(arb2).voteDispute(1, true);
  await escrow.connect(arb3).voteDispute(1, true);

  // Note: resolution happens automatically inside voteDispute once threshold is hit

  console.log("🎉 Dispute for job 1 resolved");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
});
  
