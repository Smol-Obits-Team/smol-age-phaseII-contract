const { expect } = require("chai");
const { ethers, deployments } = require("hardhat");

describe("test phase two", () => {
  let devGrounds,
    laborGrounds,
    caves,
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

    devGrounds = await ethers.getContract("DevelopmentGrounds");
    laborGrounds = await ethers.getContract("LaborGrounds");
    caves = await ethers.getContract("Caves");
    neandersmol = await ethers.getContract("NeanderSmol");
    bones = await ethers.getContract("Token");
    pits = await ethers.getContract("Pits");
    animals = await ethers.getContract("SmolAgeAnimals");
    supplies = await ethers.getContract("Supplies");
    consumables = await ethers.getContract("Consumables");
    treasure = await ethers.getContract("mERC1155");
    magic = await ethers.getContract("mERC20");
    randomizer = await ethers.getContract("Randomizer");

    const groundsAddress = [
      devGrounds.address,
      caves.address,
      laborGrounds.address,
    ];

    await neandersmol.grantStakingContracts(groundsAddress);
    await neandersmol.grantDevGround(groundsAddress[0]);

    for (addr of groundsAddress) {
      const balance = await bones.balanceOf(owner.address);
      await bones.approve(addr, balance);
    }

    const balance = await bones.balanceOf(owner.address);
    await supplies.setLaborGroundAddresss(laborGrounds.address);
    await supplies.setApprovalForAll(laborGrounds.address, true);
    await animals.setApprovalForAll(laborGrounds.address, true);
    await consumables.setAllowedAddress(laborGrounds.address, true);
    await neandersmol.publicMint(15);
    await neandersmol.connect(player).publicMint(17);

    await bones.approve(supplies.address, balance);
    await magic.approve(supplies.address, balance);
    await treasure.setApprovalForAll(supplies.address, true);

    await neandersmol.updateCommonSense(1, ethers.utils.parseEther("101"));
    await neandersmol.updateCommonSense(3, ethers.utils.parseEther("101"));
  });

  it("initializer checks", async () => {
    await expect(
      devGrounds.initialize(pits.address, neandersmol.address, bones.address)
    ).to.be.revertedWith("Initializable: contract is already initialized");
    await expect(
      laborGrounds.initialize(
        pits.address,
        animals.address,
        supplies.address,
        consumables.address,
        neandersmol.address,
        randomizer.address
      )
    ).to.be.revertedWith("Initializable: contract is already initialized");
    await expect(
      caves.initialize(pits.address, neandersmol.address, bones.address)
    ).to.be.revertedWith("Initializable: contract is already initialized");
    await expect(
      supplies.initialize(bones.address, magic.address, treasure.address, "")
    ).to.be.revertedWith("Initializable: contract is already initialized");
    await expect(pits.initialize(bones.address)).to.be.revertedWith(
      "Initializable: contract is already initialized"
    );
    await expect(consumables.initialize("")).to.be.revertedWith(
      "Initializable: contract is already initialized"
    );
  });
  describe("Pits", () => {
    it("enter pits", async () => {
      const balance = await bones.balanceOf(owner.address);
      await bones.approve(pits.address, balance);
      await expect(
        pits.stakeBonesInYard(toWei((INITIAL_SUPPLY + 1).toString()))
      ).to.be.revertedWith("BalanceIsInsufficient");
      await stakeInPit();
      expect(await pits.getBonesStaked(owner.address)).to.equal(
        toWei("3000000")
      );
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
      ).to.be.reverted;
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
  });

  describe("Developement ground", () => {
    it("enter development ground", async () => {
      await expect(
        devGrounds.enterDevelopmentGround([], [1], [0])
      ).to.be.revertedWith("LengthsNotEqual");
      await expect(
        devGrounds.enterDevelopmentGround([], [1], [0, 1])
      ).to.be.revertedWith("LengthsNotEqual");
      await expect(
        devGrounds.enterDevelopmentGround([1], [1], [1])
      ).to.be.revertedWith("DevelopmentGroundIsLocked");
      await stakeInPit();
      await expect(
        devGrounds.enterDevelopmentGround([2], [1], [1])
      ).to.be.revertedWith("CsIsBellowHundred");
      await neandersmol.updateCommonSense(16, ethers.utils.parseEther("101"));
      await expect(
        devGrounds.enterDevelopmentGround([16], [1], [1])
      ).to.be.revertedWith("NotYourToken");
      await neandersmol.updateCommonSense(1, ethers.utils.parseEther("100"));
      await expect(
        devGrounds.enterDevelopmentGround([1], [1], [1])
      ).to.be.revertedWith("InvalidLockTime");
      const tx = await devGrounds.enterDevelopmentGround(
        [1, 3],
        [toDays(50), toDays(150)],
        [0, 1]
      );
      await expect(
        neandersmol.transferFrom(owner.address, player.address, 1)
      ).to.be.revertedWith("TokenIsStaked");
      const txRes = await tx.wait();
      const blockBefore = await ethers.provider.getBlock(
        txRes.logs[0].blockNumber
      );
      expect(txRes).to.emit("EnterDevelopmentGround");
      const info = await devGrounds.getDevelopmentGroundInfo(1);
      expect(info.owner).to.equal(owner.address);
      expect(info.lockPeriod).to.equal(toDays(50));
      expect(info.entryTime).to.equal(blockBefore.timestamp);
      expect((await devGrounds.getDevelopmentGroundInfo(3)).ground).to.equal(1);
      expect(
        (await devGrounds.getStakedTokens(owner.address)).toString()
      ).to.equal("1,3");
    });
    it("stake bones in development ground", async () => {
      await expect(
        devGrounds.stakeBonesInDevelopmentGround([toWei("1009")], [1])
      ).to.be.revertedWith("DevelopmentGroundIsLocked");
      await stakeInPit();
      await expect(
        devGrounds.stakeBonesInDevelopmentGround([toWei("1009")], [1, 2])
      ).to.be.revertedWith("LengthsNotEqual");
      await expect(
        devGrounds
          .connect(player)
          .stakeBonesInDevelopmentGround([toWei("1000")], [2])
      ).to.be.revertedWith("BalanceIsInsufficient");
      await expect(
        devGrounds.stakeBonesInDevelopmentGround([toWei("1001")], [1])
      ).to.be.revertedWith("NeandersmolIsNotInDevelopmentGround");
      await devGrounds.enterDevelopmentGround([1], [toDays(50)], [1]);
      await expect(
        devGrounds.stakeBonesInDevelopmentGround([toWei("1001")], [1])
      ).to.be.revertedWith("WrongMultiple");
      const tx = await devGrounds.stakeBonesInDevelopmentGround(
        [toWei("3000")],
        [1]
      );
      expect(tx).to.emit("StakeBonesInDevelopmentGround");
      expect(await bones.balanceOf(devGrounds.address)).to.equal(toWei("3000"));
      const info = await devGrounds.getDevelopmentGroundInfo(1);
      expect(info.bonesStaked).to.equal(toWei("3000"));
    });
    it("claim bones in development ground", async () => {
      await expect(
        devGrounds.claimDevelopmentGroundBonesReward([1], [true, false])
      ).to.be.revertedWith("LengthsNotEqual");
      await expect(
        devGrounds.claimDevelopmentGroundBonesReward([1], [true])
      ).to.be.revertedWith("NotYourToken");
      await stakeInPit();
      await devGrounds.enterDevelopmentGround([1], [toDays(50)], [1]);
      await expect(
        devGrounds.claimDevelopmentGroundBonesReward([1], [true])
      ).to.be.revertedWith("ZeroBalanceError");
      await increaseTime(24);
      const tx = await devGrounds.claimDevelopmentGroundBonesReward(
        [1],
        [false]
      );
      const txRes = await tx.wait();
      const blockBefore = await ethers.provider.getBlock(
        txRes.logs[0].blockNumber
      );
      expect(await bones.totalSupply()).to.equal(
        toWei((INITIAL_SUPPLY + 10).toString())
      );
      expect(
        (await devGrounds.getDevelopmentGroundInfo(1)).lastRewardTime
      ).to.equal(blockBefore.timestamp);
      expect(tx).to.emit("ClaimDevelopmentGroundBonesReward");
      await stakeInPit();
      await neandersmol.updateCommonSense(3, ethers.utils.parseEther("101"));
      await devGrounds.enterDevelopmentGround([3], [toDays(150)], [1]);
      await increaseTime(72);
      await expect(
        devGrounds.claimDevelopmentGroundBonesReward([3], [true])
      ).to.be.revertedWith("WrongMultiple");
      await increaseTime(24 * 10);
      const balance = await bones.balanceOf(owner.address);

      await devGrounds.claimDevelopmentGroundBonesReward([3], [true]);

      expect(
        (await devGrounds.getDevelopmentGroundInfo(3)).bonesStaked
      ).to.equal(toWei("1000"));
      expect(await bones.totalSupply()).to.equal(
        toWei((INITIAL_SUPPLY + 1310).toString())
      );

      expect(await bones.balanceOf(owner.address)).to.equal(
        balance.add(toWei("300"))
      );

      await increaseTime(24 * 10);
      const txR = await devGrounds.claimDevelopmentGroundBonesReward(
        [3],
        [true]
      );

      expect(
        (await devGrounds.getDevelopmentGroundInfo(3)).bonesStaked
      ).to.equal(toWei("2000"));
      expect(txR).to.emit("StakeBonesInDevelopmentGround");
    });
    it("get development ground reward", async () => {
      await stakeInPit();
      await devGrounds.enterDevelopmentGround([1], [toDays(50)], [1]);
      await increaseTime(24);
      expect(await devGrounds.getDevelopmentGroundBonesReward(1)).to.equal(
        toWei("10")
      );
      await unstakeFromPit();
      await increaseTime(48);
      expect(await devGrounds.getDevelopmentGroundBonesReward(1)).to.equal(
        toWei("10")
      );
      await stakeInPit();
      await increaseTime(48);
      expect(await devGrounds.getDevelopmentGroundBonesReward(1)).to.equal(
        toWei("30")
      );
    });
    it("leave development ground", async () => {
      await expect(devGrounds.leaveDevelopmentGround([1])).to.be.revertedWith(
        "NotYourToken"
      );
      await stakeInPit();
      await devGrounds.enterDevelopmentGround([1], [toDays(50)], [1]);
      await expect(devGrounds.leaveDevelopmentGround([1])).to.be.revertedWith(
        "NeandersmolsIsLocked"
      );
      await increaseTime(100 * 24);
      await devGrounds.claimDevelopmentGroundBonesReward([1], [true]);
      const bal = await bones.balanceOf(owner.address);
      await increaseTime(30 * 24);
      const tx = await devGrounds.leaveDevelopmentGround([1]);
      expect(await bones.balanceOf(owner.address)).to.equal(
        bal.add(toWei("300"))
      );
      expect(await devGrounds.getStakedTokens(owner.address)).to.be.an("array")
        .that.is.empty;
      expect(tx).to.emit("LeaveDevelopmentGround");
    });
    it("remove bones from development ground", async () => {
      await expect(
        devGrounds.removeBones([1], [true, false])
      ).to.be.revertedWith("LengthsNotEqual");
      await stakeInPit();
      await devGrounds.enterDevelopmentGround(
        [1, 3],
        [toDays(50), toDays(150)],
        [0, 1]
      );
      await expect(devGrounds.removeBones([3], [true])).to.be.revertedWith(
        "ZeroBalanceError"
      );
      await devGrounds.stakeBonesInDevelopmentGround([toWei("1000")], [1]);
      await increaseTime(24);
      await devGrounds.stakeBonesInDevelopmentGround([toWei("2000")], [3]);
      await increaseTime(24 * 29);
      const tx = await devGrounds.removeBones([1, 3], [true, false]);
      expect(
        (await devGrounds.getDevelopmentGroundInfo(3)).bonesStaked
      ).to.equal(toWei("2000"));
      const ts = await bones.totalSupply();
      await devGrounds.removeBones([3], [true]);

      expect(parseInt(await bones.totalSupply())).to.greaterThanOrEqual(
        parseInt(ts) - parseInt(toWei("1000"))
      );
      expect(await devGrounds.bonesToTime(1)).to.be.empty;
      expect(tx).to.emit("RemoveBones");
    });

    it("get primary skill", async () => {
      await neandersmol.updateCommonSense(10, ethers.utils.parseEther("101"));
      await stakeInPit();
      await devGrounds.enterDevelopmentGround(
        [1, 3, 10],
        [toDays(50), toDays(150), toDays(100)],
        [0, 1, 2]
      );
      expect(await devGrounds.getPrimarySkill(1)).to.equal("0");
      await devGrounds.stakeBonesInDevelopmentGround(
        [toWei("1000"), toWei("1000"), toWei("1000")],
        [1, 3, 10]
      );
      await increaseTime(24);
      expect(await devGrounds.getPrimarySkill(1)).to.equal(toWei("0.1"));
      await unstakeFromPit();
      await increaseTime(72);
      await devGrounds.getPrimarySkill(1);
      expect(await devGrounds.getPrimarySkill(1)).to.equal(toWei("0.1"));
      await stakeInPit();
      await increaseTime(72);
      expect(await devGrounds.getPrimarySkill(1)).to.equal(toWei("0.4"));
      await increaseTime(23 * 24);
      await devGrounds.removeBones([1, 3, 10], [true, true, true]);
      const [mystics, ,] = await neandersmol.getPrimarySkill(1);
      expect(mystics).to.equal(toWei("2.7"));
      const [, farmers] = await neandersmol.getPrimarySkill(3);
      expect(farmers).to.equal(toWei("2.7"));
      const [, , fighters] = await neandersmol.getPrimarySkill(10);
      expect(fighters).to.equal(toWei("2.7"));
    });
    it("unstake single bones", async () => {
      await stakeInPit();
      await devGrounds.enterDevelopmentGround(
        [1, 3],
        [toDays(50), toDays(150)],
        [0, 1]
      );
      await devGrounds.stakeBonesInDevelopmentGround([toWei("1000")], [1]);
      await increaseTime(24);
      await devGrounds.stakeBonesInDevelopmentGround([toWei("1000")], [1]);
      const tx = await devGrounds.stakeBonesInDevelopmentGround(
        [toWei("2000")],
        [3]
      );
      const txRes = await tx.wait();
      const bBlock = await ethers.provider.getBlock(txRes.logs[0].blockNumber);
      await increaseTime(24 * 29);
      await expect(devGrounds.removeSingleBones(4, 1)).to.be.revertedWith(
        "NotYourToken"
      );
      await expect(devGrounds.removeSingleBones(1, 3)).to.be.revertedWith(
        "InvalidPos"
      );
      expect((await devGrounds.bonesToTime(1)).length).to.equal(2);
      await devGrounds.removeSingleBones(1, 1);
      expect((await devGrounds.bonesToTime(1)).length).to.equal(1);
      const res = await devGrounds.bonesToTime(3);
      expect(res[0].timeStaked).to.equal(bBlock.timestamp);
    });
    it("calculate bones", async () => {
      await stakeInPit();
      await devGrounds.enterDevelopmentGround(
        [1, 3],
        [toDays(50), toDays(150)],
        [0, 1]
      );
      await devGrounds.stakeBonesInDevelopmentGround([toWei("1000")], [1]);
      const res = await devGrounds.calculateBones(owner.address);
      expect(res[0]).to.equal(toWei("1000"));
    });
    it("dev ground fe info", async () => {
      await stakeInPit();
      await devGrounds.enterDevelopmentGround(
        [1, 3],
        [toDays(50), toDays(150)],
        [0, 1]
      );
      await increaseTime(24);
      const res = await devGrounds.getDevGroundFeInfo(owner.address);
      expect(res[1].timeLeft.toString()).to.equal("149");
      expect(res[0].daysStaked.toString()).to.equal("86400");
      expect(res[1].skillLevel.toString()).to.equal("0");
      expect(res[0].bonesAccured.toString()).to.equal(toWei("10"));
      expect(res[1].ground).to.equal(1);
    });
  });

  describe("Labor Ground", () => {
    it("enter labor ground", async () => {
      await expect(
        laborGrounds.enterLaborGround([2, 4], [2, 3], [1, 2])
      ).to.be.revertedWith("DevelopmentGroundIsLocked");
      await stakeInPit();
      await expect(
        laborGrounds.enterLaborGround([1], [], [1])
      ).to.be.revertedWith("LengthsNotEqual");
      await expect(
        laborGrounds.enterLaborGround([16], [1], [1])
      ).to.be.revertedWith("NotYourToken");
      await expect(
        laborGrounds.enterLaborGround([1], [1], [1])
      ).to.be.revertedWith("CsToHigh");
      await expect(
        laborGrounds.enterLaborGround([2], [0], [1])
      ).to.be.revertedWith("InvalidTokenForThisJob");
      await expect(
        laborGrounds.enterLaborGround([2], [1], [2])
      ).to.be.revertedWith("InvalidTokenForThisJob");
      await expect(
        laborGrounds.enterLaborGround([2], [2], [0])
      ).to.be.revertedWith("InvalidTokenForThisJob");

      await supplies.mint([2, 3], [5, 5], [2, 1]);
      const tx = await laborGrounds.enterLaborGround([2, 4], [2, 3], [1, 2]);
      const txRes = await tx.wait();
      const blockBefore = await ethers.provider.getBlock(
        txRes.logs[0].blockNumber
      );

      const info = await laborGrounds.getLaborGroundInfo(2);
      expect(info.owner).to.equal(owner.address);
      expect(info.lockTime).to.equal(blockBefore.timestamp);
      expect(info.supplyId).to.equal(2);
      expect((await laborGrounds.getLaborGroundInfo(4)).job).to.equal(2);
      expect((await laborGrounds.getLaborGroundInfo(4)).owner).to.equal(
        owner.address
      );
      expect(await supplies.balanceOf(laborGrounds.address, 2)).to.equal(1);
      expect(
        (await laborGrounds.getStakedTokens(owner.address)).toString()
      ).to.equal("2,4");
    });
    it("bring animals to labor ground", async () => {
      await stakeInPit();
      await expect(
        laborGrounds.bringInAnimalsToLaborGround([2], [])
      ).to.be.revertedWith("LengthsNotEqual");
      await expect(
        laborGrounds.bringInAnimalsToLaborGround([2], [3])
      ).to.be.revertedWith("NotYourToken");

      await supplies.mint([3], [1], [0]);
      await laborGrounds.enterLaborGround([2], [3], [2]);
      await laborGrounds.bringInAnimalsToLaborGround([2], [0]);
      expect((await laborGrounds.getLaborGroundInfo(2)).animalId).to.equal(0);
    });
    it("remove animals from labor ground", async () => {
      await stakeInPit();
      await supplies.mint([3], [5], [0]);
      await laborGrounds.enterLaborGround([2], [3], [2]);
      await laborGrounds.bringInAnimalsToLaborGround([2], [0]);
      await expect(
        laborGrounds.removeAnimalsFromLaborGround([1], [1])
      ).to.be.revertedWith("NotYourToken");
      await expect(
        laborGrounds.removeAnimalsFromLaborGround([3], [1])
      ).to.be.revertedWith("NotYourToken");
      await laborGrounds.removeAnimalsFromLaborGround([2], [0]);
    });
    it("bring animals and claim collectables from labor ground", async () => {
      await stakeInPit();
      await supplies.mint([1, 2, 3], [3, 2, 2], [0, 1, 2]);
      await supplies.setApprovalForAll(laborGrounds.address, true);
      await laborGrounds.enterLaborGround(
        [4, 2, 5, 6, 7, 8, 9],
        [1, 2, 3, 1, 2, 3, 1],
        [0, 1, 2, 0, 1, 2, 0]
      );
      await laborGrounds.bringInAnimalsToLaborGround(
        [4, 2, 5, 6, 7, 8],
        [0, 1, 2, 3, 4, 5]
      );
      await expect(laborGrounds.claimCollectables([4])).to.be.revertedWith(
        "CannotClaimNow"
      );
      await increaseTime(24 * 3);
      await laborGrounds.claimCollectables([2, 4, 5, 6, 7, 8]);
    });
    it("leave labor ground", async () => {
      await stakeInPit();
      await supplies.mint([1, 2], [2, 2], [0, 1]);
      await supplies.setApprovalForAll(laborGrounds.address, true);
      await laborGrounds.enterLaborGround([4, 2], [1, 2], [0, 1]);
      expect((await laborGrounds.getLaborGroundInfo(4)).owner).to.equal(
        owner.address
      );
      expect((await laborGrounds.getLaborGroundInfo(2)).owner).to.equal(
        owner.address
      );
      expect(await supplies.balanceOf(laborGrounds.address, 1)).to.equal(1);
      await increaseTime(24 * 3);
      await laborGrounds.leaveLaborGround([4]);
      expect(
        (await laborGrounds.getStakedTokens(owner.address)).toString()
      ).to.equal("2");
      await laborGrounds.leaveLaborGround([2]);
      expect(await laborGrounds.getStakedTokens(owner.address)).to.be.empty;
    });
    it("labor fe info", async () => {
      await stakeInPit();
      await supplies.mint([1, 2, 3], [3, 2, 2], [0, 1, 2]);
      await supplies.setApprovalForAll(laborGrounds.address, true);
      await laborGrounds.enterLaborGround(
        [4, 2, 5, 6, 7, 8, 9],
        [1, 2, 3, 1, 2, 3, 1],
        [0, 1, 2, 0, 1, 2, 0]
      );
      await laborGrounds.bringInAnimalsToLaborGround(
        [4, 2, 5, 6, 7, 8],
        [0, 1, 2, 3, 4, 5]
      );
      await expect(laborGrounds.claimCollectables([4])).to.be.revertedWith(
        "CannotClaimNow"
      );
      await increaseTime(24 * 3);
      await laborGrounds.claimCollectables([2, 4, 5, 6, 7, 8]);
      const res = await laborGrounds.getLaborGroundFeInfo(owner.address);
      expect(res[0].tokenId).to.equal(4);
      expect(res[0].timeLeft).to.equal(86400 * 3);
    });
  });

  describe("Caves", () => {
    it("enter caves", async () => {
      await stakeInPit();
      await expect(caves.enterCaves([16])).to.be.revertedWith("NotYourToken");
      const tx = await caves.enterCaves([1]);
      const txRes = await tx.wait();
      const blockBefore = await ethers.provider.getBlock(
        txRes.logs[0].blockNumber
      );
      const [theOwner, time] = await caves.getCavesInfo(1);
      expect(theOwner).to.equal(owner.address);
      expect(time).to.equal(blockBefore.timestamp);
    });
    it("get cave rewards", async () => {
      await stakeInPit();
      await caves.enterCaves([1]);
      await increaseTime(24);
      expect(await caves.getCavesReward(1)).to.equal(toWei("10"));
      await caves.enterCaves([2]);
      expect(await caves.getCavesReward(1)).to.equal(toWei("10"));
      await increaseTime(24);
      expect(await caves.getCavesReward(1)).to.equal(toWei("20"));
      expect(await caves.getCavesReward(2)).to.equal(toWei("10"));
    });
    it("claim cave rewards", async () => {
      await stakeInPit();
      await caves.enterCaves([1]);
      await expect(caves.claimCaveReward([1])).to.be.revertedWith(
        "ZeroBalanceError"
      );
      await increaseTime(24);
      const tx = await caves.claimCaveReward([1]);
      const txRes = await tx.wait();
      const blockBefore = await ethers.provider.getBlock(
        txRes.logs[0].blockNumber
      );
      expect((await caves.getCavesInfo(1))[2]).to.equal(blockBefore.timestamp);
      expect(await bones.totalSupply()).to.equal(
        toWei((INITIAL_SUPPLY + 10).toString())
      );
      await increaseTime(24 * 9);
      await caves.claimCaveReward([1]);
      expect(await bones.totalSupply()).to.equal(
        toWei((INITIAL_SUPPLY + 100).toString())
      );
    });
    it("leave cave", async () => {
      await stakeInPit();
      await caves.enterCaves([1]);
      await expect(caves.leaveCave([2])).to.be.revertedWith("NotYourToken");
      await expect(caves.leaveCave([1])).to.be.revertedWith(
        "NeandersmolsIsLocked"
      );
      await increaseTime(24 * 100);
      await caves.leaveCave([1]);
      const info = await caves.getCavesInfo(1);
      expect(info.owner).to.equal("0x0000000000000000000000000000000000000000");
      expect(info.lastRewardTimestamp).to.equal(0);
      expect(await bones.totalSupply()).to.equal(
        toWei((INITIAL_SUPPLY + 1000).toString())
      );
      await stakeInPit();
      await caves.enterCaves([1]);
      await increaseTime(24 * 100);
      await caves.claimCaveReward([1]);
      await caves.leaveCave([1]);

      expect(await caves.getStakedTokens(owner.address)).to.be.empty;
    });

    it("caves fe info", async () => {
      await stakeInPit();
      await caves.enterCaves([2]);
      await increaseTime(24 * 99);
      const res = await caves.getCavesFeInfo(owner.address);
      expect(res[0].stakedSmols).to.equal(2);
      expect(res[0].timeLeft).to.equal(86400);
      expect(res[0].reward).to.equal(ethers.utils.parseEther("990"));
    });
  });

  it("get address", async () => {
    expect(await devGrounds.bones()).to.equal(bones.address);
    expect(await devGrounds.pits()).to.equal(pits.address);
    expect(await devGrounds.neandersmol()).to.equal(neandersmol.address);
    expect(await laborGrounds.animals()).to.equal(animals.address);
    expect(await laborGrounds.pits()).to.equal(pits.address);
    expect(await laborGrounds.consumables()).to.equal(consumables.address);
    expect(await laborGrounds.supplies()).to.equal(supplies.address);
    expect(await laborGrounds.neandersmol()).to.equal(neandersmol.address);
    expect(await caves.bones()).to.equal(bones.address);
    expect(await caves.pits()).to.equal(pits.address);
    expect(await caves.neandersmol()).to.equal(neandersmol.address);
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
      supplies.connect(player).setLaborGroundAddresss(pits.address)
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
