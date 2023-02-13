module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  if (chainId === 31337) {
    await deploy("SmolAgeAnimals", {
      from: deployer,
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          methodName: "initialize",
          args: [],
        },
      },
      log: true,
    });
  }
};

module.exports.tags = ["all", "animals"];
