import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import { HardhatUserConfig } from "hardhat/config";

const common = {
  accounts: {
    mnemonic: process.env.MNEMONIC || "",
  },
};

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  networks: {
    anvil: {
      // localhost anvil
      ...common,
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    arbitrum_nova: {
      // mainnet AnyTrust chain
      ...common,
      url: "https://nova.arbitrum.io/rpc",
      chainId: 42170,
    },
    arbitrum_one_goerli: {
      // testnet
      ...common,
      url: "https://goerli-rollup.arbitrum.io/rpc",
      chainId: 421613,
    },
    arbitrum_one: {
      // mainnet
      ...common,
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};

export default config;
