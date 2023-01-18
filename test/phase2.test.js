const { expect } = require("chai");
const { ethers, deployments } = require("hardhat");

describe("test phase two", () => {
  let phaseII,
    owner,
    player,
    neandersmol,
    bones,
    pits,
    animals,
    supplies,
    consumables;

  const INITIAL_SUPPLY = 10_000_000;

  const toDays = (n) => n * 86400;

  const increaseTime = async (n) => {
    await ethers.provider.send("evm_increaseTime", [3600 * n]);
    await ethers.provider.send("evm_mine", []);
  };

  const toWei = (n) => ethers.utils.parseEther(n);

  const stakeInPit = async () => {
    const balance = await bones.balanceOf(owner.address);
    await bones.approve(pits.address, balance);
    await pits.stakeBonesInYard((10000000 * 3) / 10);
  };

  beforeEach(async () => {
    [owner, player] = await ethers.getSigners();
    await deployments.fixture(["all"]);

    phaseII = await ethers.getContract("Phase2");
    neandersmol = await ethers.getContract("mERC721");
    bones = await ethers.getContract("Token");
    pits = await ethers.getContract("Pits");
    animals = await ethers.getContract("SmolAgeAnimals");
    supplies = await ethers.getContract("Supplies");
    consumables = await ethers.getContract("Consumables");

    neandersmol.setApprovalForAll(phaseII.address, true);
    const balance = await bones.balanceOf(owner.address);
    await bones.approve(phaseII.address, balance);
  });

  it("enter development ground", async () => {
    await expect(
      phaseII.enterDevelopmentGround([], [1], [0])
    ).to.be.revertedWith("LengthsNotEqual");
    await expect(
      phaseII.enterDevelopmentGround([], [1], [0, 1])
    ).to.be.revertedWith("LengthsNotEqual");
    await expect(
      phaseII.enterDevelopmentGround([1], [1], [1])
    ).to.be.revertedWith("DevelopmentGroundIsLocked");
    await stakeInPit();
    await expect(
      phaseII.enterDevelopmentGround([2], [1], [1])
    ).to.be.revertedWith("CsIsBellowHundred");
    neandersmol.connect(player).mint(1);
    await expect(
      phaseII.enterDevelopmentGround([16], [1], [1])
    ).to.be.revertedWith("NotYourToken");

    await expect(
      phaseII.enterDevelopmentGround([1], [1], [1])
    ).to.be.revertedWith("InvalidLockTime");

    await phaseII.enterDevelopmentGround(
      [1, 3],
      [toDays(50), toDays(150)],
      [0, 1]
    );
    const info = await phaseII.getDevelopmentGroundInfo(1);
    expect(info.owner).to.equal(owner.address);
    expect(info.lockPeriod).to.equal(toDays(50));
    expect((await phaseII.getDevelopmentGroundInfo(3)).ground).to.equal(1);
  });
});
