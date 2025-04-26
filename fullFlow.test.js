const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Full Flow Integration Test", function () {
  let escrow, client, freelancer, arb1, arb2, arb3;
  const ONE_ETH = ethers.utils.parseEther("1");

  beforeEach(async () => {
    [client, freelancer, arb1, arb2, arb3] = await ethers.getSigners();
    const Escrow = await ethers.getContractFactory("FreelanceEscrow");
    escrow = await Escrow.deploy();
    await escrow.deployed();

    // Grant arbitrator roles and stake
    await escrow.grantArbitratorRole(arb1.address);
    await escrow.grantArbitratorRole(arb2.address);
    await escrow.grantArbitratorRole(arb3.address);
    await escrow.connect(arb1).stake({ value: ONE_ETH });
    await escrow.connect(arb2).stake({ value: ONE_ETH });
    await escrow.connect(arb3).stake({ value: ONE_ETH });
  });

  it("runs through happy and dispute paths", async function () {
    // Job 0: normal completion
    await escrow.connect(client).postJob({ value: ONE_ETH });
    await escrow.connect(freelancer).acceptJob(0);
    await escrow.connect(freelancer).submitWork(0);
    await escrow.connect(client).confirmCompletion(0);

    // Job 1: dispute resolution
    await escrow.connect(client).postJob({ value: ONE_ETH });
    await escrow.connect(freelancer).acceptJob(1);
    await escrow.connect(freelancer).submitWork(1);
    await escrow.connect(client).raiseDispute(1);

    // Arbitrators vote
    await escrow.connect(arb1).voteDispute(1, true);
    await escrow.connect(arb2).voteDispute(1, true);
    await escrow.connect(arb3).voteDispute(1, false);

    const job0 = await escrow.jobs(0);
    const job1 = await escrow.jobs(1);
    expect(job0.state).to.equal(3); // Completed
    expect(job1.state).to.equal(5); // Resolved
  });
});
