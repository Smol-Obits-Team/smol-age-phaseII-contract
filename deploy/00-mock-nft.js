module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const nft = await deploy("mERC721", {
    from: deployer,
    args: [],
    log: true,
  });

  log(`Mock Nft contract successfully deployed to ${nft.address}`);
};

module.exports.tags = ["all", "nft"];
