const { ethers, network } = require("hardhat");
const { networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  let addr;

  if (chainId === 31337 || chainId === 421613) {
    const bones = await ethers.getContract("Token");
    addr = bones.address;
  } else {
    addr = networkConfig[chainId].bones;
  }

  await deploy("Pits", {
    from: deployer,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [addr],
        },
      },
    },

    log: true,
  });
};

module.exports.tags = ["all", "pits"];
