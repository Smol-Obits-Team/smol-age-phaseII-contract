module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  if (chainId === 31337) {
    const animals = await deploy("SmolAgeAnimals", {
      from: deployer,
      args: [],
      log: true,
    });

    log(`SmolAgeAnimals contract successfully deployed to ${animals.address}`);
  }
};

module.exports.tags = ["all", "animals"];
