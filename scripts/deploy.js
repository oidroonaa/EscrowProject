const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const Escrow = await hre.ethers.getContractFactory("FreelanceEscrow");
  const escrow = await Escrow.deploy({
    gasPrice: ethers.utils.parseUnits("10", "gwei"),
    gasLimit: 5_000_000,
  });
  await escrow.deployed();
  console.log("Contract deployed to:", escrow.address);
  
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error)
      process.exit(1)
})

