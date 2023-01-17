module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const supplies = await deploy("Supplies", {
    from: deployer,
    args: [],
    log: true,
  });

  log(`Supplies contract successfully deployed to ${supplies.address}`);
};

module.exports.tags = ["all", "supplies"];
