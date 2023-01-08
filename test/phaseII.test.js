const { expect } = require("chai");
const { ethers, deployments } = require("hardhat");

describe("test phase two", () => {
  let phaseII, owner, player, nft, bones;

  const increaseTime = async (n) => {
    await ethers.provider.send("evm_increaseTime", [3600 * n]);
    await ethers.provider.send("evm_mine", []);
  };

  const toWei = (n) => ethers.utils.parseEther(n);

  beforeEach(async () => {
    [owner, player] = await ethers.getSigners();
    await deployments.fixture(["all"]);

    nft = await ethers.getContract("mERC721");
    bones = await ethers.getContract("Token");
    phaseII = await ethers.getContract("PhaseII");

    nft.setApprovalForAll(phaseII.address, true);
    const balance = await bones.balanceOf(owner.address);
    await bones.approve(phaseII.address, balance);
  });
  it("enter development ground", async () => {
    await expect(phaseII.enterDevelopmentGround(1, 23, 1)).to.be.reverted;
    await phaseII.enterDevelopmentGround(1, 50 * 24 * 60 * 60, 1);
    const tokenInfo = await phaseII.getTokenInfo(1);
    expect(tokenInfo.owner).to.equal(owner.address);
  });
  it("get bones accumulated", async () => {
    await phaseII.enterDevelopmentGround(1, 50 * 24 * 60 * 60, 1);
    await increaseTime(24);
    expect(await phaseII.getReward(1)).to.equal("10");
  });
  it("claim bones and stake", async () => {
    await phaseII.enterDevelopmentGround(1, 50 * 24 * 60 * 60, 1);
    await increaseTime(24 * 120);
    await phaseII.claimReward(1, true);
    const tokenInfo = await phaseII.getTokenInfo(1);
    expect(tokenInfo.bonesStaked).to.equal("1000");
  });
  it("stake bones and develop skill", async () => {
    await phaseII.enterDevelopmentGround(1, 50 * 24 * 60 * 60, 1);
    await bones.approve(phaseII.address, toWei("2000"));
    await phaseII.stakeBonesInDevGround(1000, 1);
    await increaseTime(1);
    await phaseII.stakeBonesInDevGround(1000, 1);
    await increaseTime(23);
    expect(await phaseII.calculatePrimarySkill(1)).to.equal(toWei("1"));
    await increaseTime(1);
    expect(await phaseII.calculatePrimarySkill(1)).to.equal(toWei("2"));
  });
  it("remove bones", async () => {
    await phaseII.enterDevelopmentGround(1, 50 * 24 * 60 * 60, 1);
    await bones.approve(phaseII.address, toWei("2000"));
    await phaseII.stakeBonesInDevGround(1000, 1);
    await increaseTime(1);
    await phaseII.stakeBonesInDevGround(1000, 1);
    await increaseTime(24*30);
    await phaseII.removeBones(1, true);
  });
});
