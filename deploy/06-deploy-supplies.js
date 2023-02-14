const { network } = require("hardhat");

const { networkConfig } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  let bonesAddress, treasureAddress, magicAddress;

  const bones = await ethers.getContract("Token");
  const treasure = await ethers.getContract("mERC1155");
  const magic = await ethers.getContract("mERC20");

  if (chainId === 31337 || chainId === 421613) {
    bonesAddress = bones.address;
    treasureAddress = treasure.address;
    magicAddress = magic.address;
  } else {
    bonesAddress = networkConfig[chainId].bones;
    treasureAddress = networkConfig[chainId].treasure;
    magicAddress = networkConfig[chainId].magic;
  }

  const args = [
    bonesAddress,
    magicAddress,
    treasureAddress,
    "ipfs://QmXf9RLWoVfC2hzVFUBhka22bTqveGa8nKjUJs4tGffbjD/",
  ];

  await deploy("Supplies", {
    from: deployer,
    log: true,
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
  });
};

module.exports.tags = ["all", "supplies"];
