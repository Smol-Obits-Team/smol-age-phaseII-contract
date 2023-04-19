const { run } = require("hardhat");

const verify = async (contractAddress, args) => {
  console.log("Verifying contract...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
  } catch (e) {
    console.log(e);
  }
};

const addr = [
  "0xe27281C4c36e416f19aacAa4Ea2a83B8e3039c44",
  "0x2ae763FCF1386c68979d53E6245C85b4d66c36b8",
  "0x6B3B8bB4AE9EA3D6843377ed6156c157046B685a",
];


for(let i=0; i<addr.length; ++i) verify(addr[i], [])