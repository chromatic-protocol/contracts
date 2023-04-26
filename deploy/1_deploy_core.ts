import type { DeployFunction } from "hardhat-deploy/types";
import type { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log("network name:", network.name);

  // FIXME
  let opsAddress = ethers.constants.AddressZero;
  let keeperFeePayer = ethers.constants.AddressZero;

  let { address: oracleRegistry } = await deploy("OracleRegistry", {
    from: deployer,
  });

  // // FIXME: need ops mock or real one
  // let { address: liquidator } = await deploy("USUMLiquidator", {
  //   from: deployer,
  //   args: [opsAddress],
  // });

  // await deploy("USUMMarketFactory", {
  //   from: deployer,
  //   args: [oracleRegistry, liquidator, keeperFeePayer],
  // });
};

export default func;

func.id = "deploy_core"; // id required to prevent reexecution
func.tags = ["core"];
