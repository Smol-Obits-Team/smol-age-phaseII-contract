module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const phaseII = await deploy("PhaseII", {
    from: deployer,
    args: [],
    log: true,
  });

  log(`Phase two contract successfully deployed to ${phaseII.address}`);
};

module.exports.tags = ["all", "phase2"];
