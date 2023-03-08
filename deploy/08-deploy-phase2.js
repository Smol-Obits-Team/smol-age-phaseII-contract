const { ethers, network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  let neandersmol, bones, animals, neandersmolAddress, bonesAddress, animalsAddress, randomizerAddress
  neandersmol = await ethers.getContract("mERC721");
  bones = await ethers.getContract("Token");


  /**
   * smol - testnet and localhost
   * bones - testnet and localhost
   * animals - localhost
   * randomizer - localhost
   */
  if (chainId === 31337) {
    animals = await ethers.getContract("SmolAgeAnimals");
    randomizer = await ethers.getContract("Randomizer");
    neandersmolAddress = neandersmol.address;
    bonesAddress = bones.address;
    animalsAddress = animals.address;
    randomizerAddress = randomizer.address;
  }
  if (chainId === 421613) {
    neandersmolAddress = neandersmol.address;
    bonesAddress = bones.address;
    animalsAddress = networkConfig[chainId].animals;
    randomizerAddress = networkConfig[chainId].randomizer;
  }
  if (chainId === 42161) {
    randomizerAddress = networkConfig[chainId].randomizer;
    animalsAddress = networkConfig[chainId].animals;
    neandersmolAddress = networkConfig[chainId].neandersmol;
    bonesAddress = networkConfig[chainId].bones;
  }

  pits = await ethers.getContract("Pits");
  supplies = await ethers.getContract("Supplies");
  consumables = await ethers.getContract("Consumables");



  try {
    const dg = await deploy("DevelopmentGrounds", {
      from: deployer,
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          init: {
            methodName: "initialize",
            args: [pits.address, neandersmolAddress, bonesAddress],
          },
        },
      },
      log: true,
    });
    const caves = await deploy("Caves", {
      from: deployer,
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          init: {
            methodName: "initialize",
            args: [pits.address, bonesAddress, neandersmolAddress],
          },
        },
      },
      log: true,
    });
    const lg = await deploy("LaborGrounds", {
      from: deployer,

      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          init: {
            methodName: "initialize",
            args: [pits.address, animalsAddress, supplies.address, consumables.address, neandersmolAddress, randomizerAddress],
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
