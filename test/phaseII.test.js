const { ethers, deployments } = require("hardhat");

describe("test phase two", () => {
  let phaseII, owner, player;
  beforeEach(async () => {
    [owner, player] = await ethers.getSigners();
    await deployments.fixture(["all"]);

    phaseII = await ethers.getContract("PhaseII");
  });
});
