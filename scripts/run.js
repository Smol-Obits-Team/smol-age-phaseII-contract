const { ethers } = require("hardhat");
const main = async () => {
  const caves = await ethers.getContract("Caves");
  await caves.forceRemove(4);
  console.log("Success!");
};

main();
