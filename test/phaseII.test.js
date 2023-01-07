const { ethers, deployments } = require("hardhat");

describe("test phase two", () => {
  let phaseII, owner, player, nft, bones;

  const increaseTime = async (n) => {
    await ethers.provider.send("evm_increaseTime", [86400 * n]);
    await ethers.provider.send("evm_mine", []);
  };

  beforeEach(async () => {
    [owner, player] = await ethers.getSigners();
    await deployments.fixture(["all"]);

    nft = await ethers.getContract("mERC721");
    bones = await ethers.getContract("Token");
    phaseII = await ethers.getContract("PhaseII");

    nft.setApprovalForAll(phaseII.address, true);
  });
  it("single test", async () => {
    await phaseII.enterDevelopmentGround(1, 50 * 24 * 60 * 60, 1);
    await increaseTime(2);
    const reward = await phaseII.getReward(1);
    console.log(reward.toString());
  });
});
