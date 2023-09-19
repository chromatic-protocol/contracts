# Chromatic Protocol

Chromatic Protocol is a decentralized perpetual futures protocol that provides permissionless, trustless, and unopinionated building blocks which enable participants in the DeFi ecosystem to create balanced two-sided markets exposed to oracle price feeds and trade futures in those markets using various strategies.

It is the very first protocol that introduces the concept of partitioned LP with dynamic fees. Chromatic Protocol provides a liquidity pool divided into multiple bins with different trading fee rates. The fee rate at which trades are executed is determined based on the dynamics of taker’s trading demand and maker’s liquidity supply. This dynamic fee system achieves a balanced maker-taker equilibrium, mitigating the inherent instability of closed systems like futures markets and significantly enhancing the sustainability of the protocol.

Furthermore, Chromatic Protocol is a permissionless, open-source, non-upgradable protocol that enables the creation and trading of futures markets exposed to price feeds provided by an oracle. It is characterized by a minimalist, low-level, and unopinionated design. Market creators and participants can define customizable markets supported by the protocol to optimize and innovate, fostering a secure and optimized decentralized financial ecosystem.

Lastly, Chromatic Protocol is trustless and censorship-resistant. By eliminating trusted intermediaries and rent extraction commonly found in traditional futures markets, it ensures fair and capital-efficient trading by processing transactions based on smart contracts. Additionally, Chromatic prioritizes accessibility and censorship resistance, enabling anyone to freely participate in the decentralized financial market.

Chromatic Protocol is currently built on Arbitrum.

Please refer to our GitBook at https://chromatic-protocol.gitbook.io/docs for an overview of the Chromatic Protocol.

For the full documentation of the Chromatic Protocol contracts, you can refer to [the contract development documentation](https://chromatic.finance/docs/contracts/intro/). It will provide comprehensive information about the contracts, its functionalities, and usage examples.

## Table of Contents

- [Chromatic Protocol](#chromatic-protocol)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Compilation](#compilation)
    - [Testing](#testing)
    - [Local Development](#local-development)
    - [Deployment](#deployment)
  - [Smart Contracts](#smart-contracts)
    - [core](#core)
    - [oracle](#oracle)
    - [periphery](#periphery)
  - [Documentation](#documentation)
  - [License](#license)

## Installation

Install Foundry using the instructions
[here](https://book.getfoundry.sh/getting-started/installation.html) or via
these commands:

```
$ curl -L https://foundry.paradigm.xyz | bash
$ foundryup
```

To install the necessary dependencies, run the following command:

```shell
yarn install
```

## Usage

### Compilation

To build the smart contracts, run the following command:

```shell
yarn build
```

### Testing

To run the forge unit tests for the smart contracts, use the following command:

```shell
yarn test
```

To run the tests for the smart contracts, use the following command:

```shell
yarn hardhat test
```

You can also generate a gas report during testing by running the following command:

```shell
REPORT_GAS=true yarn hardhat test
```

### Local Development

To run a local node for development and testing purposes, use the following command:

```shell
yarn chain
```

### Deployment

To deploy the smart contracts to the desired network, update the network configuration in the hardhat.config.js file. Then, run the deployment script:

```shell
yarn deploy
```

Make sure to customize the deployment script (`deploy/*.ts`) with any additional deployment logic or parameters specific to your project.


## Smart Contracts

<!-- 여기에 core/periphery/ 등의 구분 나누어서 정리할 필요가 있음. ( depolyed address 는 체인별로 나중에 추가 ) -->

### core

| Contract Name                                                         | Description                                                                                              |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| [`KeeperFeePayer`](contracts/core/KeeperFeePayer.sol)                 | A contract that pays keeper fees using a Uniswap router.                                                 |
| [`ChromaticVault`](contracts/core/ChromaticVault.sol)                 | A contract that provides functionality for managing positions, liquidity, and fees in Chromatic markets. |
| [`ChromaticMarketFactory`](contracts/core/ChromaticMarketFactory.sol) | A contract for managing the creation and registration of Chromatic markets.                              |
| [`ChromaticMarket`](contracts/core/ChromaticMarket.sol)               | A contract that represents a Chromatic market, combining trade and liquidity functionalities.            |
| [`CLBToken`](contracts/core/CLBToken.sol)                             | A contract that represents Liquidity Bin tokens.                                                         |

### oracle

| Contract Name                                                     | Description                                                                                              |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| [`ChainlinkFeedOracle`](contracts/oracle/ChainlinkFeedOracle.sol) | A contract that provides Oracle functionality using Chainlink feeds.                                     |

### periphery

| Contract Name                                                  | Description                                                               |
| -------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [`ChromaticRouter`](contracts/periphery/ChromaticRouter.sol)   | A contract that facilitates liquidity provision and trading on Chromatic. |
| [`ChromaticAccount`](contracts/periphery/ChromaticAccount.sol) | A contract manages user accounts and positions.                           |

## Documentation

Official documentation for Chromatic Protocol can be found [here](https://chromatic-protocol.github.io/docs-preview).

## License

The primary license for Chromatic Protocol is the Businiess Source License 1.1 ( `BUSL-1.1`), see [LICENSE](./LICENSE). However, solidity code files have own SPDX headers, some files are dual licensed under `MIT`.
  - All files in `contracts/core/interfaces` and `contracts/periphery/interfaces` are licensed under `MIT`
  - Some files in `contracts/oracle` are redistributed under `Apache-2.0` orginated from [@equilibria/root](https://github.com/equilibria-xyz/root)
  - All files in `contracts/core/base/gelato` and `contracts/mocks/gelato` are orginated from [`@gelatodigital/automate`](https://github.com/gelatodigital/automate) under `ISC` license.

