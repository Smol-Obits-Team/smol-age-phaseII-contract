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

  const increaseTime = async (n) => {
    await ethers.provider.send("evm_increaseTime", [3600 * n]);
    await ethers.provider.send("evm_mine", []);
  };

  const toWei = (n) => ethers.utils.parseEther(n);

  beforeEach(async () => {
    [owner, player] = await ethers.getSigners();
    await deployments.fixture(["all"]);

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
});
