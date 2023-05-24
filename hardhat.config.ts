import "@chromatic-finance/hardhat-package"
import "@nomicfoundation/hardhat-foundry"
import "@nomicfoundation/hardhat-toolbox"
import "@nomiclabs/hardhat-ethers"
import * as dotenv from "dotenv"
import "hardhat-contract-sizer"
import "hardhat-deploy"
import { HardhatUserConfig } from "hardhat/config"
import "tsconfig-paths/register"
dotenv.config()

const MNEMONIC_JUNK =
  "test test test test test test test test test test test junk"

const common = {
  accounts: {
    mnemonic: process.env.MNEMONIC || MNEMONIC_JUNK,
    count: 10,
  },
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.15",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      // localhost anvil
      forking: {
        url: `https://arb-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_KEY}`,
        blockNumber: 18064747,
      },
      ...common,
      accounts: {
        ...common.accounts,
        mnemonic: MNEMONIC_JUNK,
      },
      saveDeployments: false,
      allowUnlimitedContractSize: true,
    },
    anvil: {
      // localhost anvil
      ...common,
      accounts: {
        ...common.accounts,
        mnemonic: MNEMONIC_JUNK,
      },
      url: "http://127.0.0.1:8545",
      chainId: 31337,
      tags: ["mockup", "core"],
      allowUnlimitedContractSize: true,
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
    gelato: 1,
    alice: 2,
    bob: 3,
    charlie: 4,
    david: 5,
    eve: 6,
    frank: 7,
    grace: 8,
    heidi: 9,
  },
  package: {
    packageJson: "package.sdk.json",
    includes: [
      "OracleProvider",
      "USUMMarket",
      "USUMMarketFactory",
      "USUMVault",
      "Account",
      "AccountFactory",
      "USUMRouter",
      "USUMLpToken",
      "AggregatorV3Interface",
      "**/IERC20.sol/*",
      "**/IERC20Metadata.sol/*",
      "**/IERC1155.sol/*",
    ],
    excludes: ["**/*Lib", "**/*Mock"],
    includeDeployed: true,
    artifactFromDeployment: true,
    excludesFromDeployed: ["KeeperFeePayer", "*Lib", "*Mock"],
    docgen: {
      sourcesDir: "contracts",
      exclude: [
        "./core/base",
        "./core/external",
        "./core/interfaces",
        "./core/libraries",
        "./mocks",
        "./peirphery/base",
        "./peirphery/interfaces",
      ],
    },
  },
}

export default config
