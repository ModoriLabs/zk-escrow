import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-verify";
import "hardhat-deploy";
import "dotenv/config";

const TESTNET_PRIVATE_KEY = process.env.TESTNET_PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000001";
const PROD_DEPLOYER_PRIVATE_KEY = process.env.PROD_DEPLOYER_PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000001";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const API_KEY_ALCHEMY = process.env.API_KEY_ALCHEMY || "";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.30",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,
      },
      evmVersion: "cancun",
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    // Ethereum networks
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${API_KEY_ALCHEMY}`,
      accounts: [PROD_DEPLOYER_PRIVATE_KEY],
      chainId: 1,
    },
    holesky: {
      url: `https://eth-holesky.g.alchemy.com/v2/${API_KEY_ALCHEMY}`,
      accounts: [TESTNET_PRIVATE_KEY],
      chainId: 17000,
    },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${API_KEY_ALCHEMY}`,
      accounts: [TESTNET_PRIVATE_KEY],
      chainId: 11155111,
    },
    // Base networks
    base: {
      url: `https://base-mainnet.g.alchemy.com/v2/${API_KEY_ALCHEMY}`,
      accounts: [PROD_DEPLOYER_PRIVATE_KEY],
      chainId: 8453,
    },
    baseSepolia: {
      url: `https://base-sepolia.g.alchemy.com/v2/${API_KEY_ALCHEMY}`,
      accounts: [TESTNET_PRIVATE_KEY],
      chainId: 84532,
    },
    // Optimism networks
    optimismSepolia: {
      url: `https://opt-sepolia.g.alchemy.com/v2/${API_KEY_ALCHEMY}`,
      accounts: [TESTNET_PRIVATE_KEY],
      chainId: 11155420,
    },
    // Kaia networks
    kaia: {
      url: "https://public-en.node.kaia.io",
      accounts: [PROD_DEPLOYER_PRIVATE_KEY],
      chainId: 8217,
      gasPrice: 250000000000,
    },
    kairos: {
      url: "https://public-en-kairos.node.kaia.io",
      accounts: [TESTNET_PRIVATE_KEY],
      chainId: 1001,
      gasPrice: 250000000000,
    },
    // Soneium networks
    minato: {
      url: process.env.MINATO_RPC_URL || "https://rpc.minato.soneium.org",
      accounts: [TESTNET_PRIVATE_KEY],
      chainId: 1946,
    },
    soneium: {
      url: process.env.SONEIUM_RPC_URL || "https://rpc.soneium.org",
      accounts: [PROD_DEPLOYER_PRIVATE_KEY],
      chainId: 1868,
    },
  },
  etherscan: {
    apiKey: {
      kairos: "unnecessary",
      kaia: "unnecessary",
    },
    customChains: [
      {
        network: "kairos",
        chainId: 1001,
        urls: {
          apiURL: "https://kairos-api.kaiascan.io/hardhat-verify",
          browserURL: "https://kairos.kaiascan.io",
        }
      },
      {
        network: "kaia",
        chainId: 8217,
        urls: {
          apiURL: "https://mainnet-api.kaiascan.io/hardhat-verify",
          browserURL: "https://kaiascan.io",
        }
      },
    ]
  },
  sourcify: {
    enabled: false,
  },
  paths: {
    sources: "./src",
    tests: "./test",
    cache: "./cache_hardhat",
    artifacts: "./artifacts",
    deploy: "./deploy",
    deployments: "./deployments",
  },
  namedAccounts: {
    deployer: {
      default: 0, // First account as deployer
      1: 0, // mainnet
      8453: 0, // base
      84532: 0, // base sepolia
      1001: 0, // kairos
      8217: 0, // kaia
    },
  },
};

export default config;
