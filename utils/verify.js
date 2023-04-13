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
  "0x598874F16084DD98Bbf41e7Eae609E634f1FeAfc",
  "0x2d9AAB6330E8BF492fb3A78FD898207bDcFA9106",
  "0xCA8408760bd4f0A7266b1aFf3cc3B3c7820C9B24",
];

for (let i = 0; i < addr.length; ++i) verify(addr[i], []);
