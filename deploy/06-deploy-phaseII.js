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

  const phaseII = await deploy("PhaseII", {
    from: deployer,
    args: [
      pits.address,
      bones.address,
      animals.address,
      supplies.address,
      consumables.address,
      neandersmol.address,
    ],
    log: true,
  });

  log(`Phase two contract successfully deployed to ${phaseII.address}`);
};

module.exports.tags = ["all", "phase2"];
