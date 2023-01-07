module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const bones = await deploy("Token", {
    from: deployer,
    args: [],
    log: true,
  });

  log(`Mock Bones contract successfully deployed to ${bones.address}`);
};

module.exports.tags = ["all", "bones"];
