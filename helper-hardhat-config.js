const networkConfig = {
  42161: {
    name: "arbitrum",
    neandersmol: "0x6b86936967a328b327a6b8deafda9884f5006832",
    magic: "0x539bde0d7dbd336b79148aa742883198bbf60342",
    bones: "0x74912f00bda1c2030cf33e7194803259426e64a4",
    treasure: "0xc5295c6a183f29b7c962df076819d44e0076860e",
    animals: "0x0dd35869e1c11767aa044da506e4d31459a9d028",
    randomizer: "0x8e79c8607a28fe1EC3527991C89F1d9E36D1bAd9",
  },

  421613: {
    name: "arbitrumGoerli",
    randomizer: "0x9b58fc8c7B224Ae8479DA7E6eD37CA4Ac58099a9",
    animals: "0xca8f5e151465a99504f9f176d9daf3dcfc702945",
  },
};

const developmentChains = ["hardhat", "localhost"];

module.exports = {
  networkConfig,
  developmentChains,
};
