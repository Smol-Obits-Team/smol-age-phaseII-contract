const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const neandersmol = await ethers.getContract("mERC721");
  const bones = await ethers.getContract("Token");
  const pits = await ethers.getContract("Pits");
  const animals = await ethers.getContract("SmolAgeAnimals");
  const supplies = await ethers.getContract("Supplies");
  const consumables = await ethers.getContract("Consumables");

  const helperLibrary = await deploy("Lib", {
    from: deployer,
  });
  const args = [
    pits.address,
    bones.address,
    animals.address,
    supplies.address,
    consumables.address,
    neandersmol.address,
  ];
  const phase2 = await deploy("Phase2", {
    from: deployer,
    args,
    libraries: {
      Rewards: helperLibrary.address,
    },
    log: true,
  });

  log(`Phase two contract successfully deployed to ${phase2.address}`);
};

module.exports.tags = ["all", "phase2"];
