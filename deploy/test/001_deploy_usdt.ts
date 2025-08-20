import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy, getOrNull } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Deploying USDT on", network.name);
  console.log("Deployer:", deployer);

  // Check if USDT already exists
  const existingUSDT = await getOrNull("USDT");

  if (existingUSDT) {
    console.log("USDT already deployed at:", existingUSDT.address);
    return;
  }

  // Deploy USDT (MockUSDT contract)
  const usdt = await deploy("USDT", {
    contract: "MockUSDT", // Use MockUSDT contract but deploy as "USDT"
    from: deployer,
    args: [deployer],
    log: true,
  });

  console.log("\n=== USDT DEPLOYMENT SUMMARY ===");
  console.log("USDT:", usdt.address);
  console.log("===================================\n");
};

export default func;
func.tags = ["USDT", "test"];
func.dependencies = [];

// Only run this on test networks
func.skip = async (hre: HardhatRuntimeEnvironment) => {
  const chainId = parseInt(await hre.getChainId());

  // Skip on mainnet chains (1 = Ethereum mainnet, 8453 = Base mainnet, 8217 = Kaia mainnet)
  const mainnetChains = [1, 8453, 8217];
  return mainnetChains.includes(chainId);
};
