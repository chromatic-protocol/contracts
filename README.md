# Chromatic Protocol

Chromatic, a cutting-edge open-source protocol operating on the robust Arbitrum network, revolutionizes the DeFi landscape by unlocking the power of futures functionality. By facilitating the creation of two-sided markets, Chromatic empowers participants to engage in seamless trading, while amplifying their exposure to underlying price feeds.

Distinguished by its trustless and non-upgradable nature, Chromatic redefines the rules of the game by eliminating the need for intermediaries and eradicating rent extraction. This ensures a level playing field, fostering an environment of fairness and efficiency. Moreover, Chromatic places utmost importance on accessibility, capital efficiency, and censorship resistance, allowing users of all backgrounds to leverage the protocol's benefits.

With its minimalist, low-level, and unopinionated design philosophy, Chromatic empowers market creators and participants to unleash their creativity, optimize their strategies, and drive innovation within customizable markets. By offering a secure and optimized framework for decentralized finance, Chromatic sets the stage for transformative advancements in the industry.

One of the groundbreaking features of Chromatic lies in its dynamic fee system, which addresses the inherent volatility and imbalances prevalent in closed systems like futures markets. Through an ingenious mechanism based on market supply and demand, Chromatic ensures a balanced maker-taker equilibrium, fostering sustainability and equilibrium within the protocol. This dynamic fee structure serves as a cornerstone of the protocol's resilience and paves the way for a harmonious trading environment.

In summary, Chromatic emerges as a trailblazer in the realm of DeFi, leveraging the power of Arbitrum to introduce futures functionality with unrivaled trustlessness and innovation. By prioritizing accessibility, capital efficiency, and censorship resistance, while embracing dynamic fee mechanisms, Chromatic ushers in a new era of decentralized finance, redefining the possibilities and potential of the ecosystem.

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
| [`ChromaticLiquidator`](contracts/core/ChromaticLiquidator.sol)       | A contract that handles the liquidation and claiming of positions in Chromatic markets.                  |
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

