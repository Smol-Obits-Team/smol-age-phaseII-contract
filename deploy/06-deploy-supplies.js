module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const bones = await ethers.getContract("Token");
  const treasure = await ethers.getContract("mERC1155");
  const magic = await ethers.getContract("mERC20");

  const args = [bones.address, magic.address, treasure.address, "ipfs://QmXf9RLWoVfC2hzVFUBhka22bTqveGa8nKjUJs4tGffbjD/"];

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
