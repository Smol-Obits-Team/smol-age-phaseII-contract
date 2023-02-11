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
    treasure,
    magic,
    randomizer,
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
    treasure = await ethers.getContract("mERC1155");
    magic = await ethers.getContract("mERC20");
    randomizer = await ethers.getContract("Randomizer");

    neandersmol.setApprovalForAll(phaseII.address, true);
    const balance = await bones.balanceOf(owner.address);
    await bones.approve(phaseII.address, balance);
    await supplies.setPhase2Addresss(phaseII.address);
    await supplies.setApprovalForAll(phaseII.address, true);
    await animals.setApprovalForAll(phaseII.address, true);
    await neandersmol.connect(player).mint(1);
    await consumables.setAllowedAddress(phaseII.address, true);
    await bones.approve(supplies.address, balance);
    await magic.approve(supplies.address, balance);
    await treasure.setApprovalForAll(supplies.address, true);
  });

  it("initializers checks", async () => {
    await expect(
      phaseII.initialize(
        pits.address,
        bones.address,
        animals.address,
        supplies.address,
        consumables.address,
        neandersmol.address,
        randomizer.address
      )
    ).to.be.revertedWith("Initializable: contract is already initialized");
    await expect(
      supplies.initialize(pits.address, bones.address, animals.address, "")
    ).to.be.revertedWith("Initializable: contract is already initialized");
    await expect(pits.initialize(bones.address)).to.be.revertedWith(
      "Initializable: contract is already initialized"
    );
    await expect(consumables.initialize("")).to.be.revertedWith(
      "Initializable: contract is already initialized"
    );
  });

  it("enter pits", async () => {
    const balance = await bones.balanceOf(owner.address);
    await bones.approve(pits.address, balance);
    await expect(
      pits.stakeBonesInYard(toWei((INITIAL_SUPPLY + 1).toString()))
    ).to.be.revertedWith("BalanceIsInsufficient");
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

  it("check pits rej", async () => {
    await expect(
      pits.stakeBonesInYard(toWei((INITIAL_SUPPLY * 3).toString()))
    ).to.be.revertedWith("BalanceIsInsufficient");
    await expect(
      pits.stakeBonesInYard(toWei(((INITIAL_SUPPLY * 3) / 10).toString()))
    ).to.be.revertedWith("0x7939f424");
    const balance = await bones.balanceOf(owner.address);
    await bones.approve(pits.address, balance);
    const tx = await pits.stakeBonesInYard(
      toWei(((INITIAL_SUPPLY * 3) / 10).toString())
    );
    const txRes = await tx.wait();
    const blockBefore = await ethers.provider.getBlock(
      txRes.logs[0].blockNumber
    );
    expect(await pits.totalDaysOff()).to.equal("0");
    expect(await pits.getDaysOff(blockBefore.timestamp)).to.equal("0");

    await expect(
      pits.removeBonesFromYard(toWei(INITIAL_SUPPLY.toString()))
    ).to.be.revertedWith("BalanceIsInsufficient");
    const txr = await pits.removeBonesFromYard(toWei("1000"));
    const txR = await txr.wait();
    const blockB = await ethers.provider.getBlock(txR.logs[0].blockNumber);
    expect(await pits.timeOut()).to.equal(blockB.timestamp);
    await increaseTime(24);
    await pits.stakeBonesInYard(toWei("1200"));
    expect(await pits.getDaysOff(blockB.timestamp)).to.equal("1");
    expect(await pits.totalDaysOff()).to.equal("1");
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
      phaseII.stakeBonesInDevelopmentGround([toWei("1001")], [1])
    ).to.be.revertedWith("TokenNotInDevelopmentGround");
    await phaseII.enterDevelopmentGround([1], [toDays(50)], [1]);
    await expect(
      phaseII.stakeBonesInDevelopmentGround([toWei("1001")], [1])
    ).to.be.revertedWith("WrongMultiple");
    const tx = await phaseII.stakeBonesInDevelopmentGround(
      [toWei("3000")],
      [1]
    );
    expect(tx).to.emit("StakeBonesInDevelopmentGround");
    expect(await bones.balanceOf(phaseII.address)).to.equal(toWei("3000"));
    const info = await phaseII.getDevelopmentGroundInfo(1);
    expect(info.bonesStaked).to.equal(toWei("3000"));
  });
  it("claim bones in development ground", async () => {
    await expect(
      phaseII.claimDevelopmentGroundBonesReward([1], [true, false])
    ).to.be.revertedWith("LengthsNotEqual");
    await expect(
      phaseII.claimDevelopmentGroundBonesReward([1], [true])
    ).to.be.revertedWith("NotYourToken");
    await stakeInPit();
    await phaseII.enterDevelopmentGround([1], [toDays(50)], [1]);
    await expect(
      phaseII.claimDevelopmentGroundBonesReward([1], [true])
    ).to.be.revertedWith("ZeroBalanceError");
    await increaseTime(24);
    const tx = await phaseII.claimDevelopmentGroundBonesReward([1], [false]);
    const txRes = await tx.wait();
    const blockBefore = await ethers.provider.getBlock(
      txRes.logs[0].blockNumber
    );
    expect(await bones.totalSupply()).to.equal(
      toWei((INITIAL_SUPPLY + 10).toString())
    );
    expect((await phaseII.getDevelopmentGroundInfo(1)).lastRewardTime).to.equal(
      blockBefore.timestamp
    );
    expect(tx).to.emit("ClaimDevelopmentGroundBonesReward");
    await stakeInPit();
    await phaseII.enterDevelopmentGround([3], [toDays(150)], [1]);
    await increaseTime(72);
    await expect(
      phaseII.claimDevelopmentGroundBonesReward([3], [true])
    ).to.be.revertedWith("WrongMultiple");
    await increaseTime(24 * 10);
    const balance = await bones.balanceOf(owner.address);

    await phaseII.claimDevelopmentGroundBonesReward([3], [true]);

    expect((await phaseII.getDevelopmentGroundInfo(3)).bonesStaked).to.equal(
      toWei("1000")
    );
    expect(await bones.totalSupply()).to.equal(
      toWei((INITIAL_SUPPLY + 1310).toString())
    );

    expect(await bones.balanceOf(owner.address)).to.equal(
      balance.add(toWei("300"))
    );

    await increaseTime(24 * 10);
    const txR = await phaseII.claimDevelopmentGroundBonesReward([3], [true]);

    expect((await phaseII.getDevelopmentGroundInfo(3)).bonesStaked).to.equal(
      toWei("2000")
    );
    expect(txR).to.emit("StakeBonesInDevelopmentGround");
  });
  it("get development ground reward", async () => {
    await stakeInPit();
    await phaseII.enterDevelopmentGround([1], [toDays(50)], [1]);
    await increaseTime(24);
    expect(await phaseII.getDevelopmentGroundBonesReward(1)).to.equal(
      toWei("10")
    );
    await unstakeFromPit();
    await increaseTime(48);
    expect(await phaseII.getDevelopmentGroundBonesReward(1)).to.equal(
      toWei("10")
    );
    await stakeInPit();
    await increaseTime(48);
    expect(await phaseII.getDevelopmentGroundBonesReward(1)).to.equal(
      toWei("30")
    );
  });
  it("leave development ground", async () => {
    await expect(phaseII.leaveDevelopmentGround([1])).to.be.revertedWith(
      "NotYourToken"
    );
    await stakeInPit();
    await phaseII.enterDevelopmentGround([1], [toDays(50)], [1]);
    await expect(phaseII.leaveDevelopmentGround([1])).to.be.revertedWith(
      "NeandersmolsIsLocked"
    );
    await increaseTime(100 * 24);
    await phaseII.claimDevelopmentGroundBonesReward([1], [true]);
    const bal = await bones.balanceOf(owner.address);
    await increaseTime(30 * 24);
    const tx = await phaseII.leaveDevelopmentGround([1]);
    expect(await bones.balanceOf(owner.address)).to.equal(
      bal.add(toWei("300"))
    );
    expect(tx).to.emit("LeaveDevelopmentGround");
  });
  it("remove bones from development ground", async () => {
    await expect(phaseII.removeBones([1], [true, false])).to.be.revertedWith(
      "LengthsNotEqual"
    );
    await stakeInPit();
    await phaseII.enterDevelopmentGround(
      [1, 3],
      [toDays(50), toDays(150)],
      [0, 1]
    );
    await expect(phaseII.removeBones([3], [true])).to.be.revertedWith(
      "ZeroBalanceError"
    );
    await phaseII.stakeBonesInDevelopmentGround([toWei("1000")], [1]);
    await increaseTime(24);
    await phaseII.stakeBonesInDevelopmentGround([toWei("2000")], [3]);
    await increaseTime(24 * 29);
    const tx = await phaseII.removeBones([1, 3], [true, false]);
    expect((await phaseII.getDevelopmentGroundInfo(3)).bonesStaked).to.equal(
      toWei("2000")
    );
    await phaseII.removeBones([3], [true]);
    expect(
      await bones.balanceOf("0x0000000000000000000000000000000000000001")
    ).to.equal(toWei("1000"));
    expect(tx).to.emit("RemoveBones");
  });

  it("get primary skill", async () => {
    await stakeInPit();
    await phaseII.enterDevelopmentGround(
      [1, 3, 10],
      [toDays(50), toDays(150), toDays(100)],
      [0, 1, 2]
    );
    expect(await phaseII.getPrimarySkill(1)).to.equal("0");
    await phaseII.stakeBonesInDevelopmentGround(
      [toWei("1000"), toWei("1000"), toWei("1000")],
      [1, 3, 10]
    );
    await increaseTime(24);
    expect(await phaseII.getPrimarySkill(1)).to.equal(toWei("0.1"));
    await unstakeFromPit();
    await increaseTime(72);
    await phaseII.getPrimarySkill(1);
    expect(await phaseII.getPrimarySkill(1)).to.equal(toWei("0.1"));
    await stakeInPit();
    await increaseTime(72);
    expect(await phaseII.getPrimarySkill(1)).to.equal(toWei("0.4"));
    await increaseTime(23 * 24);
    await phaseII.removeBones([1, 3, 10], [true, true, true]);
    const [mystics, ,] = await neandersmol.getPrimarySkill(1);
    expect(mystics).to.equal(toWei("2.7"));
    const [, farmers] = await neandersmol.getPrimarySkill(3);
    expect(farmers).to.equal(toWei("2.7"));
    const [, , fighters] = await neandersmol.getPrimarySkill(10);
    expect(fighters).to.equal(toWei("2.7"));
  });

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

    await supplies.mint([2, 3], [5, 5], [2, 1]);
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

    await supplies.mint([3], [1], [0]);
    await phaseII.enterLaborGround([2], [3], [2]);
    await phaseII.bringInAnimalsToLaborGround([2], [0]);
    expect((await phaseII.getLaborGroundInfo(2)).animalId).to.equal(1);
  });
  it("remove animals from labor ground", async () => {
    await supplies.mint([3], [5], [0]);
    await phaseII.enterLaborGround([2], [3], [2]);
    await phaseII.bringInAnimalsToLaborGround([2], [0]);
    await expect(
      phaseII.removeAnimalsFromLaborGround([1], [1])
    ).to.be.revertedWith("NotYourToken");
    await expect(
      phaseII.removeAnimalsFromLaborGround([3], [1])
    ).to.be.revertedWith("NotYourToken");
    await phaseII.removeAnimalsFromLaborGround([2], [0]);
  });
  it("bring animals and claim collectables from labor ground", async () => {
    await supplies.mint([1, 2, 3], [3, 2, 2], [0, 1, 2]);
    await supplies.setApprovalForAll(phaseII.address, true);
    await phaseII.enterLaborGround(
      [4, 2, 5, 6, 7, 8, 9],
      [1, 2, 3, 1, 2, 3, 1],
      [0, 1, 2, 0, 1, 2, 0]
    );
    await phaseII.bringInAnimalsToLaborGround(
      [4, 2, 5, 6, 7, 8],
      [0, 1, 2, 3, 4, 5]
    );
    // token 4 either get 1 or 4
    // token 2 either gets 2 or 5
    await expect(phaseII.claimCollectables([4])).to.be.revertedWith(
      "CannotClaimNow"
    );
    await increaseTime(24 * 3);
    await phaseII.claimCollectables([2, 4, 5, 6, 7, 8]);
  });
  it("leave labor ground", async () => {
    await supplies.mint([1, 2], [2, 2], [0, 1]);
    await supplies.setApprovalForAll(phaseII.address, true);
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
  it("get address", async () => {
    const [a, b, c, d, e, f, g] = await phaseII.getAddress();
    expect(a).to.equal(pits.address);
    expect(b).to.equal(bones.address);
    expect(c).to.equal(animals.address);
    expect(d).to.equal(supplies.address);
    expect(e).to.equal(randomizer.address);
    expect(f).to.equal(consumables.address);
    expect(g).to.equal(neandersmol.address);
  });
  it("supplies tests", async () => {
    expect(await supplies.name()).to.equal("Supplies");
    expect(await supplies.symbol()).to.equal("supplies");
    expect(await supplies.uri(1)).to.equal(
      "ipfs://QmXf9RLWoVfC2hzVFUBhka22bTqveGa8nKjUJs4tGffbjD/1"
    );
    expect(await supplies.owner()).to.equal(owner.address);
    await expect(supplies.mint([1], [3], [])).to.be.revertedWith(
      "LengthsNotEqual"
    );
    await expect(supplies.mint([4], [3], [1])).to.be.revertedWith(
      "InvalidTokenId"
    );
    await expect(supplies.mint([0], [3], [1])).to.be.revertedWith(
      "InvalidTokenId"
    );
    await expect(
      supplies.setApprovalForAll(pits.address, true)
    ).to.be.revertedWith("NotAuthorized");
    await expect(
      supplies.connect(player).setPhase2Addresss(pits.address)
    ).to.be.revertedWith("Unauthorized");
  });
  it("consumables", async () => {
    expect(await consumables.name()).to.equal("Consumables");
    expect(await consumables.symbol()).to.equal("consumables");
    expect(await consumables.uri(1)).to.equal(
      "ipfs://QmZyUXadJvNRWq99nKbtxL66ZmP2Z8faWDTdFsGYyJnS84/1"
    );

    await expect(
      consumables.connect(player).setAllowedAddress(pits.address, true)
    ).to.be.revertedWith("Unauthorized");
    await expect(consumables.mint(owner.address, 1, 1)).to.be.revertedWith(
      "NotAuthorized"
    );
  });
});
