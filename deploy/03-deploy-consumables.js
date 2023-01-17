module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const consumables = await deploy("Consumables", {
    from: deployer,
    args: [],
    log: true,
  });

  log(`Consumables contract successfully deployed to ${consumables.address}`);
};

module.exports.tags = ["all", "consumables"];
