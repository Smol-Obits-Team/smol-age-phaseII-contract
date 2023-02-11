const { ethers, network } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  const bones = await ethers.getContract("Token");
  let addr;

  if (chainId != 42161) addr = bones.address;
  else addr = "0x74912f00bda1c2030cf33e7194803259426e64a4";

  const pits = await deploy("Pits", {
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
