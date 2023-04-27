import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-toolbox";
import "@usum-io/hardhat-package";
import * as dotenv from "dotenv";
import "hardhat-contract-sizer";
import "hardhat-deploy";
import { HardhatUserConfig } from "hardhat/config";
dotenv.config();

const MNEMONIC_JUNK =
  "test test test test test test test test test test test junk";

const common = {
  accounts: {
    mnemonic: process.env.MNEMONIC || "",
  },
};

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: "anvil",
  networks: {
    anvil: {
      // localhost anvil
      ...common,
      accounts: {
        mnemonic: MNEMONIC_JUNK,
      },
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      tags: ["mockup", "core"],
    },
    arbitrum_nova: {
      // mainnet AnyTrust chain
      ...common,
      url: "https://nova.arbitrum.io/rpc",
      chainId: 42170,
      tags: ["core"],
    },
    arbitrum_one_goerli: {
      // testnet
      ...common,
      url: "https://goerli-rollup.arbitrum.io/rpc",
      chainId: 421613,
      tags: ["core"],
    },
    arbitrum_one: {
      // mainnet
      ...common,
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
      tags: ["core"],
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  package: {
    packageJson: "package.sdk.json",
  },
};

export default config;
