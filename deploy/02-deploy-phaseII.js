const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const nft = await ethers.getContract("mERC721");
  const bones = await ethers.getContract("Token");

  const phaseII = await deploy("PhaseII", {
    from: deployer,
    args: [nft.address, bones.address],
    log: true,
  });

  log(`Phase two contract successfully deployed to ${phaseII.address}`);
};

module.exports.tags = ["all", "phase2"];
