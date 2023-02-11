module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("Consumables", {
    from: deployer,
    proxy: {
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: ["ipfs://QmZyUXadJvNRWq99nKbtxL66ZmP2Z8faWDTdFsGYyJnS84/"],
        },
      },
    },
    log: true,
  });
};

module.exports.tags = ["all", "consumables"];
