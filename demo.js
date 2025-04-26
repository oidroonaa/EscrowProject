const { ethers } = require("hardhat");

async function main() {
  // 1) Grab all the actors up front
  const [client, freelancer, arb1, arb2, arb3] = await ethers.getSigners();

  // 2) Attach to your deployed address
  const escrowAddress = process.argv[2];
  if (!escrowAddress) {
    console.error("Usage: node demo.js <ESCROW_ADDRESS>");
    process.exit(1);
  }
  const Escrow = await ethers.getContractFactory("FreelanceEscrow");
  const escrow = Escrow.attach(escrowAddress);

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
  console.log("\n🔨 Raising dispute on job 1...");
  await escrow.connect(client).postJob({ value: ethers.utils.parseEther("1") });
  await escrow.connect(freelancer).acceptJob(1);
  await escrow.connect(freelancer).submitWork(1);
  await escrow.connect(client).raiseDispute(1);

  // 5) Voting
  console.log("🗳️  Arbitrators staking & voting...");
  // (Assumes they already staked in your deploy script or tests)
  await escrow.connect(arb1).voteDispute(1, true);
  await escrow.connect(arb2).voteDispute(1, true);
  await escrow.connect(arb3).voteDispute(1, false);

  // Note: resolution happens automatically inside voteDispute once threshold is hit

  console.log("🎉 Dispute for job 1 resolved");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });

  