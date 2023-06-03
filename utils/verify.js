const { run } = require("hardhat");

const verify = async (contractAddress) => {
  console.log("Verifying contract...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: [],
    });
  } catch (e) {
    console.log(e);
  }
};

