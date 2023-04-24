require("hardhat-deploy");
require("dotenv").config();
require("solidity-coverage");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@openzeppelin/hardhat-upgrades");

const ARBITRUM_GOERLI_RPC = process.env.ARBITRUM_GOERLI_RPC || "";
const ARBITRUM_RPC_URL = process.env.ARBITRUM_RPC_URL || "";
const ARBISCAN_API_KEY = process.env.ARBISCAN_API_KEY || "";

const PRIVATE_KEY_0 = process.env.PRIVATE_KEY_0;
const PRIVATE_KEY_1 = process.env.PRIVATE_KEY_1;
const REPORT_GAS = process.env.REPORT_GAS || true;

module.exports = {
  defaultNetwork: "hardhat",

  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      chainId: 31337,
    },
    arbitrumgoerli: {
      url: ARBITRUM_GOERLI_RPC,
      accounts: PRIVATE_KEY_0 !== undefined ? [PRIVATE_KEY_0] : [],
      saveDeployments: true,
      chainId: 421613,
      blockConfirmations: 6,
    },
    arbitrum: {
      url: ARBITRUM_RPC_URL,
      accounts: PRIVATE_KEY_1 !== undefined ? [PRIVATE_KEY_1] : [],
      saveDeployments: true,
      chainId: 42161,
      blockConfirmations: 6,
    },
  },

  gasReporter: {
    enabled: REPORT_GAS,
    currency: "USD",
    outputFile: "gas-report.txt",
    noColors: true,
  },
  contractSizer: {
    runOnCompile: true,
  },
  namedAccounts: {
    deployer: {
      default: 0,
      1: 0,
    },
    feeCollector: {
      default: 1,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.18",
      },
      {
        version: "0.8.13",
      },
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  etherscan: {
    apiKey: ARBISCAN_API_KEY,
  },
  mocha: {
    timeout: 200000, // 200 seconds max for running tests
  },
};
