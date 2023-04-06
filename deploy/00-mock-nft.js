const { network } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  if (chainId !== 42161) {
    await deploy("NeanderSmol", {
      from: deployer,
      log: true,
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          init: {
            methodName: "initialize",
            args: [],
          },
        },
      },
    });
  }
};

module.exports.tags = ["all", "nft"];
