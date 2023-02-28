const { ethers, network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  let neandersmolAddress, bonesAddress, animalsAddress, randomizerAddress;
  const neandersmol = await ethers.getContract("mERC721");
  const animals = await ethers.getContract("SmolAgeAnimals");
  const randomizer = await ethers.getContract("Randomizer");
  const bones = await ethers.getContract("Token");
  /**
   * smol - testnet and localhost
   * bones - testnet and localhost
   * animals - localhost
   * randomizer - localhost
   */
  if (chainId === 31337) {
    neandersmolAddress = neandersmol.address;
    bonesAddress = bones.address;
    animalsAddress = animals.address;
    randomizerAddress = randomizer.address;
  }
  if (chainId === 421613) {
    neandersmolAddress = neandersmol.address;
    bonesAddress = bones.address;
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

  const helperLibrary = await deploy("Lib", {
    from: deployer,
  });

  try {
    await deploy("DevelopmentGrounds", {
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
            args: [pits.address, neandersmol.address, bones.address],
          },
        },
      },
      log: true,
    });
    await deploy("Caves", {
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
            args: [pits.address, bones.address, neandersmol.address],
          },
        },
      },
      log: true,
    });
    await deploy("LaborGrounds", {
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
            args: [pits.address, animals.address, supplies.address, consumables.address, neandersmol.address, randomizer.address],
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
