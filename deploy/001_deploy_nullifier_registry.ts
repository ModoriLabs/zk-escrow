import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Deploying NullifierRegistry on", network.name);
  console.log("Deployer:", deployer);

  const nullifierRegistry = await deploy("NullifierRegistry", {
    from: deployer,
    args: [deployer],
    log: true,
  });

  console.log("NullifierRegistry deployed at:", nullifierRegistry.address);
};

export default func;
func.tags = ["NullifierRegistry"];
func.dependencies = [];