module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  if (chainId !== 42161) {
    await deploy("mERC20", {
      from: deployer,
      proxy: {
        owner: deployer,
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          init: {
            methodName: "initialize",
            args: [],
          },
        },
      },
      log: true,
    });
  }
};

module.exports.tags = ["all", "magic"];
