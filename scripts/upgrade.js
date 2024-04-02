const { ethers, upgrades } = require("hardhat");

const main = async () => {
  const proxyAddress = "0xbE342A5836E820d0a3f0AcbF28D8e7822328A7d8";
  const devGroundFactory = await ethers.getContractFactory(
    "contracts/DevelopmentGroundsOld.sol:DevelopmentGrounds"
  );

  console.log(
    "Implementation address: " +
      (await upgrades.erc1967.getImplementationAddress(proxyAddress))
  );

  console.log(
    "Admin address: " + (await upgrades.erc1967.getAdminAddress(proxyAddress))
  );

  await upgrades.forceImport(proxyAddress, devGroundFactory, {
    kind: "transparent",
  });

  console.log("------Fetching prev info------");

  const devGroundV2Factory = await ethers.getContractFactory(
    "contracts/DevelopmentGrounds.sol:DevelopmentGrounds"
  );

  const dg = await upgrades.upgradeProxy(proxyAddress, devGroundV2Factory);
  await dg.deployed();
  console.log("------Successfully deployed ------");
};

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
