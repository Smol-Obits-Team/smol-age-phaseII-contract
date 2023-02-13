module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  if (chainId === 31337) {
    await deploy("Randomizer", {
      from: deployer,
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
      },
      log: true,
    });
  }
};

module.exports.tags = ["all", "randomizer"];
