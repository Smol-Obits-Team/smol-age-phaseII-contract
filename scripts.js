const { ethers } = require("hardhat");

const main = async () => {
  const caFac = await ethers.getContract("DevelopmentGrounds");
  const id = [2946, 4524, 1300, 336];
  const tx = await caFac.f(id);
  const txRes = await tx.wait();
  console.log(txRes);
};

main();
