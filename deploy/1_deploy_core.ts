import type { DeployFunction } from "hardhat-deploy/types";
import type { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network, ethers } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  console.log("network name:", network.name);

  const res = await deploy("OracleRegistry", {
    from: deployer,
  });

  await deploy("USUMFactory", {
    from: deployer,
    args: [res.address],
  });
};

export default func;

func.id = "deploy_core"; // id required to prevent reexecution
func.tags = ["core"];
