import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { getChainNameForEscrow } from "../scripts/utils/deployment";

const INTENT_EXPIRATION_PERIOD = 1800; // 30 minutes

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network, getChainId } = hre;
  const { deploy, get, getOrNull } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();
  const chainName = getChainNameForEscrow(parseInt(chainId));

  console.log("Deploying EscrowUpgradeable on", network.name, "with chain ID", chainId);
  console.log("Deployer:", deployer);

  // Get NullifierRegistry from previous deployment
  const nullifierRegistry = await get("NullifierRegistry");
  const nullifierRegistryAddress = nullifierRegistry.address;
  console.log("Using NullifierRegistry at:", nullifierRegistryAddress);

  // Deploy EscrowUpgradeable with UUPS proxy
  const escrowProxy = await deploy("EscrowUpgradeable", {
    from: deployer,
    proxy: {
      proxyContract: "UUPS",
      execute: {
        init: {
          methodName: "initialize",
          args: [deployer, INTENT_EXPIRATION_PERIOD, chainName],
        },
      },
    },
    log: true,
  });

  const escrowProxyAddress = escrowProxy.address;
  console.log("Escrow proxy deployed at:", escrowProxyAddress);

  // Log deployment summary
  console.log("\n=== ESCROW DEPLOYMENT SUMMARY ===");
  console.log("Escrow Proxy:", escrowProxyAddress);
  console.log("NullifierRegistry:", nullifierRegistryAddress);
  console.log("===================================\n");
};

export default func;
func.tags = ["EscrowUpgradeable"];
// func.dependencies = ["NullifierRegistry"];
