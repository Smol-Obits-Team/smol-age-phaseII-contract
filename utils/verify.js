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

const addr = [
  "0x409D8139Bf35528235EE020A80760969a66724Dd",
  "0x6a49Ed246748D0B81A8a6f3362BD673774354B2C",
  "0x17f75a8cF862d3CbC44725B3DdAb05aD2723922D",
];


for(let i=0; i<addr.length; ++i) verify(addr[i])