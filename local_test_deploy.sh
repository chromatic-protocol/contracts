#!/bin/bash
cd ../mate2-contract/ 
yarn deploy:anvil
cd ../contracts
KEEPER_ADDRESS=$(cat ../mate2-contract/deployments/anvil/MantleKeeperRegistry.json | jq '.address')
echo $KEEPER_ADDRESS
sed -i "" -r "s/31337: .*$/31337: $KEEPER_ADDRESS,/" deploy/2_deploy_core_mantle.ts
yarn hardhat deploy --network anvil --reset --tags core,mantle,periphery,mockup ; yarn hardhat typechain
yarn hardhat package --typechain-target ethers-v5 --build-dir package-build-v5 --build false
yarn wagmi generate
cp wagmi/index.ts  ../sdk/packages/sdk-viem/src/gen/index.ts
cd ../sdk/packages/sdk-viem
yarn build