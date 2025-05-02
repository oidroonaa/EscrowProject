const { expect } = require("chai");
const { ethers, network } = require("hardhat");

describe("Full Flow Integration Test", function () {
  let escrow, client, freelancer, arb1, arb2, arb3;
  const ONE_ETH = ethers.utils.parseEther("1");

  beforeEach(async () => {
    [client, freelancer, arb1, arb2, arb3] = await ethers.getSigners();

    // Deploy fresh contract
    const Escrow = await ethers.getContractFactory("FreelanceEscrow");
    escrow = await Escrow.deploy();
    await escrow.deployed();

    // Grant arbitrator roles
    await escrow.grantArbitratorRole(arb1.address);
    await escrow.grantArbitratorRole(arb2.address);
    await escrow.grantArbitratorRole(arb3.address);

    // Stake 1 ETH each
    await escrow.connect(arb1).stake({ value: ONE_ETH });
    await escrow.connect(arb2).stake({ value: ONE_ETH });
    await escrow.connect(arb3).stake({ value: ONE_ETH });

    // Fast-forward 1 hour so voting cooldown is over
    await network.provider.send("evm_increaseTime", [3600]);
    await network.provider.send("evm_mine");
  });

  it("runs through happy and dispute paths", async () => {
    // ─── Job 0: Happy Path ───────────────────────────────────────────────
    await escrow.connect(client).postJob({ value: ONE_ETH });   // jobId = 0
    await escrow.connect(freelancer).acceptJob(0);
    await escrow.connect(freelancer).submitWork(0);
    await escrow.connect(client).confirmCompletion(0);

    const job0 = await escrow.jobs(0);
    expect(job0.state).to.equal(3); // State.Completed

    // ─── Job 1: Dispute Path ───────────────────────────────────────────
    await escrow.connect(client).postJob({ value: ONE_ETH });   // jobId = 1
    await escrow.connect(freelancer).acceptJob(1);
    await escrow.connect(freelancer).submitWork(1);
    await escrow.connect(client).raiseDispute(1);

    // **NEW**: Submit evidence so voteDispute won't revert
    const evidenceHash = ethers.utils.id("dummy-evidence");
    const evidenceURI  = "ipfs://QmDummyCid";
    await escrow
      .connect(client)
      .submitEvidence(1, evidenceHash, evidenceURI);

    // Now the three arbitrators can vote
    await escrow.connect(arb1).voteDispute(1, true);
    await escrow.connect(arb2).voteDispute(1, false);
    await escrow.connect(arb3).voteDispute(1, true);

    const job1 = await escrow.jobs(1);
    expect(job1.state).to.equal(5); // State.Resolved
  });
});
