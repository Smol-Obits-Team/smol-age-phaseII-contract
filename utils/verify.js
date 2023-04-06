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
  "0xB704163b3Eb66dF2B9f6A942fAb88263A3b215A9",
  "0xE640EEFcb9eBfdC5398FeC9905a0ea86c64B9841",
  "0x87a80A2E3A42981973F20782625Dd3e7053Ae89f",
  "0x83bC8A59cFEcFfb82979c8882F65a61eA72fb9c7",
  "0x720c51Aa2D8a952D67c6DE6E1786EF9376c768C2",
  "0x52592b0b845a0F0a02018C0Ae455335d2a18C63e",
  "0xe7aEbde34BE658d778025398eEAEDea412B265C6",
  "0xd6D86293aC90f40de7ad5ad1E6E69C02459769c8",
  "0xCd3eC032edC99AfB86d367ce6BbD98392e9A8723",
  "0x73032eF96FEE3C84f95121BdAc5dbCe68E757D97",
];

for (let i = 0; i < addr.length; ++i) {
  verify(addr[i], []);
}
