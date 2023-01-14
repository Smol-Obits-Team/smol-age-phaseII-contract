const { expect } = require("chai");
const { ethers, deployments } = require("hardhat");

describe("test phase two", () => {
  let phaseII, owner, player, nft, bones;

  const INITIAL_SUPPLY = 10_000_000;

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
    const tokenInfo = await phaseII.getDevelopmentGroundInfo(1);
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
    expect(await bones.balanceOf(phaseII.address)).to.equal(toWei("1000"));
    expect(await bones.balanceOf(owner.address)).to.equal(
      toWei((INITIAL_SUPPLY + 200).toString())
    );
    expect((await phaseII.getDevelopmentGroundInfo(1)).bonesStaked).to.equal("1000");
    await increaseTime(24 * 100);
    await phaseII.claimReward(1, true);
    expect(await bones.balanceOf(phaseII.address)).to.equal(toWei("2000"));
    await increaseTime(24);
    await phaseII.claimReward(1, false);
    expect(await bones.totalSupply()).to.equal(
      toWei((INITIAL_SUPPLY + 1000 + 1000 + 200 + 10).toString())
    );
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
    await bones.approve(phaseII.address, toWei("5000"));
    await phaseII.stakeBonesInDevGround(1000, 1);

    await phaseII.removeBones(1, true);
    expect(await phaseII.trackTime(1, 1)).to.equal("0");
    await phaseII.stakeBonesInDevGround(1000, 1);
    expect((await phaseII.getDevelopmentGroundInfo(1)).amountPosition).to.equal("1");
    await increaseTime(24);
    await phaseII.stakeBonesInDevGround(1000, 1);
    expect((await phaseII.getDevelopmentGroundInfo(1)).amountPosition).to.equal("2");
    const secondTime = await phaseII.trackTime(1, 2);
    await increaseTime(24 * 29);
    await phaseII.removeBones(1, false);
    expect(await phaseII.trackTime(1, 1)).to.equal(secondTime.toString());
    expect((await phaseII.getDevelopmentGroundInfo(1)).bonesStaked).to.equal("1000");
    expect((await phaseII.getDevelopmentGroundInfo(1)).amountPosition).to.equal("1");
  });
  it("leave development ground", async () => {
    await phaseII.enterDevelopmentGround(1, 50 * 24 * 60 * 60, 0);
    await phaseII.enterDevelopmentGround(2, 50 * 24 * 60 * 60, 1);
    await phaseII.enterDevelopmentGround(3, 50 * 24 * 60 * 60, 2);
    await bones.approve(phaseII.address, toWei("5000"));
    await phaseII.stakeBonesInDevGround(1000, 1);
    await phaseII.stakeBonesInDevGround(1000, 3);
    await phaseII.stakeBonesInDevGround(1000, 2);
    await increaseTime(24 * 50);
    await phaseII.leaveDevelopmentGround(1);
    await phaseII.leaveDevelopmentGround(2);
    await phaseII.leaveDevelopmentGround(3);
    expect((await nft.getPrimarySkill(1)).mystics).to.equal(toWei("50"));
    expect((await nft.getPrimarySkill(2)).farmers).to.equal(toWei("50"));
    expect((await nft.getPrimarySkill(3)).fighters).to.equal(toWei("50"));
  });
});
