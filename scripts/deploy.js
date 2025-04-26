const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();


  const Escrow = await hre.ethers.getContractFactory("FreelanceEscrow");
  const escrow = await Escrow.deploy();
  await escrow.deployed();
  console.log("Contract deployed to:", escrow.address);
  
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error)
      process.exit(1)
})

