const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const bones = await ethers.getContract("Token");

  const pits = await deploy("Pits", {
    from: deployer,
    args: [bones.address],
    log: true,
  });

  log(`Pits contract successfully deployed to ${pits.address}`);
};

module.exports.tags = ["all", "pits"];
