const { ethers, network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  let neandersmolAddress, bonesAddress, animalsAddress, randomizerAddress;

  if (chainId === 31337 || chainId === 421613) {
    const neandersmol = await ethers.getContract("mERC721");
    neandersmolAddress = neandersmol.address;
    const bones = await ethers.getContract("Token");
    bonesAddress = bones.address;
    const randomizer = await ethers.getContract("Randomizer");
    randomizerAddress = randomizer.address;
  } else {
    neandersmolAddress = networkConfig[chainId].neandersmol;
    bonesAddress = networkConfig[chainId].bones;
    animalsAddress = networkConfig[chainId].animals;
    randomizerAddress = networkConfig[chainId].randomizer;
  }

  pits = await ethers.getContract("Pits");
  supplies = await ethers.getContract("Supplies");
  consumables = await ethers.getContract("Consumables");

  const helperLibrary = await deploy("Lib", {
    from: deployer,
  });
  const args = [
    pits.address,
    bonesAddress,
    animalsAddress,
    supplies.address,
    consumables.address,
    neandersmolAddress,
    randomizerAddress,
  ];

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
