# Chromatic Protocol

Chromatic, a cutting-edge open-source protocol operating on the robust Arbitrum network, revolutionizes the DeFi landscape by unlocking the power of futures functionality. By facilitating the creation of two-sided markets, Chromatic empowers participants to engage in seamless trading, while amplifying their exposure to underlying price feeds.

Distinguished by its trustless and non-upgradable nature, Chromatic redefines the rules of the game by eliminating the need for intermediaries and eradicating rent extraction. This ensures a level playing field, fostering an environment of fairness and efficiency. Moreover, Chromatic places utmost importance on accessibility, capital efficiency, and censorship resistance, allowing users of all backgrounds to leverage the protocol's benefits.

With its minimalist, low-level, and unopinionated design philosophy, Chromatic empowers market creators and participants to unleash their creativity, optimize their strategies, and drive innovation within customizable markets. By offering a secure and optimized framework for decentralized finance, Chromatic sets the stage for transformative advancements in the industry.

One of the groundbreaking features of Chromatic lies in its dynamic fee system, which addresses the inherent volatility and imbalances prevalent in closed systems like futures markets. Through an ingenious mechanism based on market supply and demand, Chromatic ensures a balanced maker-taker equilibrium, fostering sustainability and equilibrium within the protocol. This dynamic fee structure serves as a cornerstone of the protocol's resilience and paves the way for a harmonious trading environment.

In summary, Chromatic emerges as a trailblazer in the realm of DeFi, leveraging the power of Arbitrum to introduce futures functionality with unrivaled trustlessness and innovation. By prioritizing accessibility, capital efficiency, and censorship resistance, while embracing dynamic fee mechanisms, Chromatic ushers in a new era of decentralized finance, redefining the possibilities and potential of the ecosystem.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
  - [Compilation](##compilation)
  - [Testing](##testing)
  - [Local Development](##local-development)
  - [Deployment](##deployment)
- [Smart Contracts](#smart-contracts)
- [Contributing](#contributing)
- [License](#license)
- [Documentation](#documentation)
- [Contact](#contact)

## Installation

To install the necessary dependencies, run the following command:

```shell
npm install
```

## Usage

To get the usage help message, run the following command:

```shell
npx hardhat help
```


### Compilation

To compile the smart contracts, run the following command:

```shell
npm complie
```

### Testing

To run the tests for the smart contracts, use the following command:

```shell
npx hardhat test
```

You can also generate a gas report during testing by running the following command:

```shell
REPORT_GAS=true npx hardhat test
```

### Local Development

To run a local Hardhat node for development and testing purposes, use the following command:

```shell
npx hardhat node
```

### Deployment

To deploy the smart contracts to the desired network, update the network configuration in the hardhat.config.js file. Then, run the deployment script:

```shell
npx hardhat run scripts/deploy.ts
```

Make sure to customize the deployment script (`deploy.ts`) with any additional deployment logic or parameters specific to your project.


## Smart Contracts

여기에 core/peripheral/ 등의 구분 나누어서 정리할 필요가 있음. ( depolyed address 는 체인별로 나중에 추가 )

| Contract Name    | Description                       | Source File                    | 
| ---------------- | --------------------------------- | ------------------------------ |
| Contract 1       | Description of Contract 1         | [Link to Contract 1](contract1.sol) |
| Contract 2       | Description of Contract 2         | [Link to Contract 2](contract2.sol) |
| ...              | ...                               | ...                            |


## Contributing

여기에 contribute.md 파일 링크 연결하면 될 듯. ( contribute.md 는 우리 라이센스에 맞게 적절한 거 가져와야 할 듯 )

## License

[Specify the license under which your project is released. Choose an appropriate license that suits your needs. You can include the full license text or provide a link to it.]

## Documentation

Official documentation for Chromatic Protocol can be found [here](https://docs.chromatic.finance).

## Contact

[Provide contact information for users to reach out to you if they have questions, suggestions, or feedback about Chromatic protocol. You can include your email address, social media handles, or a link to a dedicated support channel.]
