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
    await pits.stakeBonesInYard(toWei(((INITIAL_SUPPLY * 3) / 10).toString()));
  };

  const unstakeFromPit = async () => {
    const balance = await bones.balanceOf(owner.address);
    await bones.approve(pits.address, balance);
    await pits.removeBonesFromYard(toWei((INITIAL_SUPPLY / 10).toString()));
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
    await supplies.setApprovalForAll(phaseII.address, true);
    await animals.setApprovalForAll(phaseII.address, true);
  });

  it("enter pits", async () => {
    await stakeInPit();
    expect(await pits.getBonesStaked(owner.address)).to.equal(toWei("3000000"));
    expect(await pits.getTotalBonesStaked()).to.equal(toWei("3000000"));
  });

  it("leave pits", async () => {
    await stakeInPit();
    await unstakeFromPit();
    const bal = ((INITIAL_SUPPLY * 3 - INITIAL_SUPPLY) / 10).toString();
    expect(await pits.getTotalBonesStaked()).to.equal(toWei(bal));
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

    const tx = await phaseII.enterDevelopmentGround(
      [1, 3],
      [toDays(50), toDays(150)],
      [0, 1]
    );
    const txRes = await tx.wait();
    const blockBefore = await ethers.provider.getBlock(
      txRes.logs[0].blockNumber
    );
    const info = await phaseII.getDevelopmentGroundInfo(1);
    expect(info.owner).to.equal(owner.address);
    expect(info.lockPeriod).to.equal(toDays(50));
    expect(info.lockTime).to.equal(blockBefore.timestamp);
    expect((await phaseII.getDevelopmentGroundInfo(3)).ground).to.equal(1);
  });

  // some test to be done at this point
  it("enter labor ground", async () => {
    await expect(phaseII.enterLaborGround([1], [], [1])).to.be.revertedWith(
      "LengthsNotEqual"
    );
    await neandersmol.connect(player).mint(1);
    await expect(phaseII.enterLaborGround([16], [1], [1])).to.be.revertedWith(
      "NotYourToken"
    );
    await expect(phaseII.enterLaborGround([1], [1], [1])).to.be.revertedWith(
      "CsToHigh"
    );
    await expect(phaseII.enterLaborGround([2], [0], [1])).to.be.revertedWith(
      "InvalidTokenForThisJob"
    );
    await expect(phaseII.enterLaborGround([2], [1], [2])).to.be.revertedWith(
      "InvalidTokenForThisJob"
    );
    await expect(phaseII.enterLaborGround([2], [2], [0])).to.be.revertedWith(
      "InvalidTokenForThisJob"
    );

    const tx = await phaseII.enterLaborGround([2, 4], [2, 3], [1, 2]);
    const txRes = await tx.wait();
    const blockBefore = await ethers.provider.getBlock(
      txRes.logs[0].blockNumber
    );

    const info = await phaseII.getLaborGroundInfo(2);
    expect(info.owner).to.equal(owner.address);
    expect(info.lockTime).to.equal(blockBefore.timestamp);
    expect(info.supplyId).to.equal(2);
    expect((await phaseII.getLaborGroundInfo(4)).job).to.equal(2);
    expect((await phaseII.getLaborGroundInfo(4)).owner).to.equal(owner.address);
    expect(await supplies.balanceOf(phaseII.address, 2)).to.equal(1);
  });
  it("bring animals to labor ground", async () => {
    await expect(
      phaseII.bringInAnimalsToLaborGround([2], [])
    ).to.be.revertedWith("LengthsNotEqual");
    await expect(
      phaseII.bringInAnimalsToLaborGround([2], [3])
    ).to.be.revertedWith("NotYourToken");
    await phaseII.enterLaborGround([2], [3], [2]);
    await phaseII.bringInAnimalsToLaborGround([2], [0]);
    expect((await phaseII.getLaborGroundInfo(2)).animalId).to.equal(1);
  });
  it("claim collectables and from labor ground", async () => {
    await phaseII.enterLaborGround([4, 2], [1, 2], [0, 1]);
    await phaseII.bringInAnimalsToLaborGround([4, 2], [0, 2]);
    // token 4 either get 1 or 4
    // token 2 either gets 2 or 5
    await expect(phaseII.claimCollectable(4)).to.be.revertedWith(
      "CannotClaimNow"
    );
    await increaseTime(24 * 3);
    await phaseII.claimCollectable(4);
    await phaseII.claimCollectable(2);
  });
  it("leave labor ground", async () => {
    await phaseII.enterLaborGround([4, 2], [1, 2], [0, 1]);
    expect((await phaseII.getLaborGroundInfo(4)).owner).to.equal(owner.address);
    expect((await phaseII.getLaborGroundInfo(2)).owner).to.equal(owner.address);
    expect(await supplies.balanceOf(phaseII.address, 1)).to.equal(1);
    await increaseTime(24 * 3);
    await phaseII.leaveLaborGround([4]);
  });
});
