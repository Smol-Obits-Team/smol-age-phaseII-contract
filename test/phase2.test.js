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
    await neandersmol.connect(player).mint(1);
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
    expect(txRes).to.emit("EnterDevelopmentGround");
    const info = await phaseII.getDevelopmentGroundInfo(1);
    expect(info.owner).to.equal(owner.address);
    expect(info.lockPeriod).to.equal(toDays(50));
    expect(info.lockTime).to.equal(blockBefore.timestamp);
    expect((await phaseII.getDevelopmentGroundInfo(3)).ground).to.equal(1);
  });
  it("stake bones in development ground", async () => {
    await expect(
      phaseII.stakeBonesInDevelopmentGround([toWei("1009")], [1])
    ).to.be.revertedWith("DevelopmentGroundIsLocked");
    await stakeInPit();
    await expect(
      phaseII.stakeBonesInDevelopmentGround([toWei("1009")], [1, 2])
    ).to.be.revertedWith("LengthsNotEqual");
    await expect(
      phaseII
        .connect(player)
        .stakeBonesInDevelopmentGround([toWei("1000")], [2])
    ).to.be.revertedWith("BalanceIsInsufficient");
    await expect(
      phaseII.stakeBonesInDevelopmentGround([toWei("1000")], [1])
    ).to.be.revertedWith("TokenNotInDevelopementGround");
    await expect(
      phaseII.stakeBonesInDevelopmentGround([toWei("1001")], [1])
    ).to.be.revertedWith("TokenNotInDevelopementGround");
    await phaseII.enterDevelopmentGround([1], [toDays(50)], [1]);
    await expect(
      phaseII.stakeBonesInDevelopmentGround([toWei("1001")], [1])
    ).to.be.revertedWith("WrongMultiple");
    const tx = await phaseII.stakeBonesInDevelopmentGround(
      [toWei("3000")],
      [1]
    );
    expect(tx).to.emit("StakeBonesInDevelopmentGround");
    const info = await phaseII.getDevelopmentGroundInfo(1);
    expect(info.bonesStaked).to.equal(toWei("3000"));
  });

  // some test to be done at this point
  it("enter labor ground", async () => {
    await expect(phaseII.enterLaborGround([1], [], [1])).to.be.revertedWith(
      "LengthsNotEqual"
    );
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
    await expect(phaseII.claimCollectables([4])).to.be.revertedWith(
      "CannotClaimNow"
    );
    await increaseTime(24 * 3);
    await phaseII.claimCollectables([4]);
    await phaseII.claimCollectables([2]);
  });
  it("leave labor ground", async () => {
    await phaseII.enterLaborGround([4, 2], [1, 2], [0, 1]);
    expect((await phaseII.getLaborGroundInfo(4)).owner).to.equal(owner.address);
    expect((await phaseII.getLaborGroundInfo(2)).owner).to.equal(owner.address);
    expect(await supplies.balanceOf(phaseII.address, 1)).to.equal(1);
    await increaseTime(24 * 3);
    await phaseII.leaveLaborGround([4]);
  });
  it("enter caves", async () => {
    await expect(phaseII.enterCaves([16])).to.be.revertedWith("NotYourToken");
    const tx = await phaseII.enterCaves([1]);
    const txRes = await tx.wait();
    const blockBefore = await ethers.provider.getBlock(
      txRes.logs[0].blockNumber
    );
    const [theOwner, time] = await phaseII.getCavesInfo(1);
    expect(theOwner).to.equal(owner.address);
    expect(time).to.equal(blockBefore.timestamp);
  });
  it("get cave rewards", async () => {
    await phaseII.enterCaves([1]);
    await increaseTime(24);
    expect(await phaseII.getCavesReward(1)).to.equal(toWei("10"));
    await phaseII.enterCaves([2]);
    expect(await phaseII.getCavesReward(1)).to.equal(toWei("10"));
    await increaseTime(24);
    expect(await phaseII.getCavesReward(1)).to.equal(toWei("20"));
    expect(await phaseII.getCavesReward(2)).to.equal(toWei("10"));
  });
  it("claim cave rewards", async () => {
    await phaseII.enterCaves([1]);
    await expect(phaseII.claimCaveReward([1])).to.be.revertedWith(
      "ZeroBalanceError"
    );
    await increaseTime(24);
    const tx = await phaseII.claimCaveReward([1]);
    const txRes = await tx.wait();
    const blockBefore = await ethers.provider.getBlock(
      txRes.logs[0].blockNumber
    );
    expect((await phaseII.getCavesInfo(1))[1]).to.equal(blockBefore.timestamp);
    expect(await bones.totalSupply()).to.equal(
      toWei((INITIAL_SUPPLY + 10).toString())
    );
    await increaseTime(24 * 9);
    await phaseII.claimCaveReward([1]);
    expect(await bones.totalSupply()).to.equal(
      toWei((INITIAL_SUPPLY + 100).toString())
    );
  });
  it("leave cave", async () => {
    await phaseII.enterCaves([1]);
    await expect(phaseII.leaveCave([2])).to.be.revertedWith("NotYourToken");
    await expect(phaseII.leaveCave([1])).to.be.revertedWith(
      "NeandersmolsIsLocked"
    );
    await increaseTime(24 * 100);
    await phaseII.leaveCave([1]);
    const [theOwner, time] = await phaseII.getCavesInfo(1);
    expect(theOwner).to.equal("0x0000000000000000000000000000000000000000");
    expect(time).to.equal("0");
    expect(await bones.totalSupply()).to.equal(
      toWei((INITIAL_SUPPLY + 1000).toString())
    );
  });
  it("calculate reward", async () => {
    await stakeInPit();
    await phaseII.enterDevelopmentGround(
      [1, 3],
      [toDays(50), toDays(150)],
      [0, 1]
    );
    await increaseTime(24);

    const res = await phaseII.getDevelopmentGroundBonesReward(1);
    console.log(res.toString()); // 10 1 day
    await unstakeFromPit();
    await increaseTime(48);
    const resII = await phaseII.getDevelopmentGroundBonesReward(1);
    console.log(resII.toString()); // 10 3 days
    await stakeInPit();
    await increaseTime(48);
    const resIII = await phaseII.getDevelopmentGroundBonesReward(1);
    console.log(resIII.toString()); // 30 5 days
    const balance = await bones.balanceOf(pits.address);
    await pits.removeBonesFromYard(balance);
    await stakeInPit();
    await increaseTime(120);
    const resIV = await phaseII.getDevelopmentGroundBonesReward(1);
    console.log(resIV.toString()); // 80 7 days
  });
});
