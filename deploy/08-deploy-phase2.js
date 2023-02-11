const { ethers, network } = require("hardhat");
const {
  networkConfig,
  developmentChains,
} = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  let neandersmol, bones, pits, animals, supplies, consumables, randomizer;

  if (chainId === 31337) {
    neandersmol = await ethers.getContract("mERC721");
    bones = await ethers.getContract("Token");
    pits = await ethers.getContract("Pits");
    animals = await ethers.getContract("SmolAgeAnimals");
    randomizer = await ethers.getContract("Randomizer");
  }

  if (chainId === 42161) {
    neandersmol = networkConfig["42161"].neandersmol;
    bones = networkConfig["42161"].bones;
    animals = networkConfig["42161"].animals;
  }

  supplies = await ethers.getContract("Supplies");
  consumables = await ethers.getContract("Consumables");

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
    randomizer.address,
  ];

  // can create a function to sort the correct address for the current chainId

  try {
    await deploy("Phase2", {
      from: deployer,
      libraries: {
        Lib: helperLibrary.address,
      },
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          init: {
            methodName: "initialize",
            args,
          },
        },
      },
      log: true,
    });
  } catch (e) {
    console.log(e);
  }
};

module.exports.tags = ["all", "phase2"];
