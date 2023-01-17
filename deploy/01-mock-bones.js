module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  if (chainId === 31337) {
    const bones = await deploy("Token", {
      from: deployer,
      args: [],
      log: true,
    });

    log(`Mock Bones contract successfully deployed to ${bones.address}`);
  }
};

module.exports.tags = ["all", "bones"];
