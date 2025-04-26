const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FreelanceEscrow Contract", function () {
  let escrow;
  let admin, client, freelancer, arb1, arb2, arb3;
  const ONE_ETH = ethers.utils.parseEther("1");

  beforeEach(async () => {
    [admin, client, freelancer, arb1, arb2, arb3] = await ethers.getSigners();

    const Escrow = await ethers.getContractFactory("FreelanceEscrow");
    escrow = await Escrow.deploy();
    await escrow.deployed();

    // Grant arbitrator roles
    await escrow.grantArbitratorRole(arb1.address);
    await escrow.grantArbitratorRole(arb2.address);
    await escrow.grantArbitratorRole(arb3.address);
  });

  it("allows a client to post a job with ETH", async () => {
    await expect(() =>
      escrow.connect(client).postJob({ value: ONE_ETH })
    ).to.changeEtherBalances(
      [client, escrow],
      [ONE_ETH.mul(-1), ONE_ETH]
    );

    const job = await escrow.jobs(0);
    expect(job.client).to.equal(client.address);
    expect(job.amount).to.equal(ONE_ETH);
    expect(job.state).to.equal(0); // Posted
  });

  it("rejects posting a job with zero ETH", async () => {
    await expect(
      escrow.connect(client).postJob({ value: 0 })
    ).to.be.revertedWith("Must fund job");
  });

  it("handles accept, submit, and confirm completion flow", async () => {
    // Post and accept
    await escrow.connect(client).postJob({ value: ONE_ETH });
    await escrow.connect(freelancer).acceptJob(0);
    let job = await escrow.jobs(0);
    expect(job.freelancer).to.equal(freelancer.address);
    expect(job.state).to.equal(1); // Accepted

    // Submit work
    await escrow.connect(freelancer).submitWork(0);
    job = await escrow.jobs(0);
    expect(job.state).to.equal(2); // Submitted

    // Confirm completion and transfer funds
    await expect(() =>
      escrow.connect(client).confirmCompletion(0)
    ).to.changeEtherBalances(
      [escrow, freelancer],
      [ONE_ETH.mul(-1), ONE_ETH]
    );
    job = await escrow.jobs(0);
    expect(job.state).to.equal(3); // Completed
  });

  it("allows raising a dispute after submission", async () => {
    await escrow.connect(client).postJob({ value: ONE_ETH });
    await escrow.connect(freelancer).acceptJob(0);
    await escrow.connect(freelancer).submitWork(0);

    await expect(
      escrow.connect(client).raiseDispute(0)
    ).to.emit(escrow, "DisputeRaised").withArgs(0);

    const job = await escrow.jobs(0);
    expect(job.state).to.equal(4); // Disputed
  });

  it("requires at least 1 ETH to stake", async () => {
    await expect(
      escrow.connect(arb1).stake({ value: ONE_ETH.sub(1) })
    ).to.be.revertedWith("Must stake >= 1 ETH");
  });

  it("prevents unstaking more than available stake", async () => {
    await escrow.connect(arb1).stake({ value: ONE_ETH });
    await expect(
      escrow.connect(arb1).unstake(ONE_ETH.add(1))
    ).to.be.revertedWith("Insufficient available stake");
  });
});
