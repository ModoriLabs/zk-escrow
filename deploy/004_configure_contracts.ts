import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { get } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Configuring contracts on", network.name);
  console.log("Deployer:", deployer);

  // Get all deployed contracts
  const nullifierRegistry = await get("NullifierRegistry");
  const escrow = await get("EscrowUpgradeable");
  const tossBankVerifier = await get("TossBankReclaimVerifierV2");

  const nullifierRegistryAddress = nullifierRegistry.address;
  const escrowProxyAddress = escrow.address;
  const tossBankVerifierAddress = tossBankVerifier.address;

  // Get contract instances
  const nullifierRegistryContract = await ethers.getContractAt("NullifierRegistry", nullifierRegistryAddress);
  const escrowContract = await ethers.getContractAt("EscrowUpgradeable", escrowProxyAddress);
  const tossBankVerifierContract = await ethers.getContractAt("TossBankReclaimVerifierV2", tossBankVerifierAddress);

  // Check and add write permission to NullifierRegistry
  const hasWritePermission = await nullifierRegistryContract.isWriter(tossBankVerifierAddress);
  if (!hasWritePermission) {
    console.log("Adding write permission to TossBankReclaimVerifierV2...");
    const tx1 = await nullifierRegistryContract.addWritePermission(tossBankVerifierAddress);
    await tx1.wait();
    console.log("Write permission added");
  } else {
    console.log("TossBankReclaimVerifierV2 already has write permission");
  }

  // Add verifier to escrow whitelist
  try {
    console.log("Adding TossBankReclaimVerifierV2 to Escrow whitelist...");
    const tx2 = await escrowContract.addWhitelistedPaymentVerifier(tossBankVerifierAddress);
    await tx2.wait();
    console.log("Verifier whitelisted");
  } catch (error: any) {
    if (error.message.includes("already whitelisted") || error.message.includes("revert")) {
      console.log("TossBankReclaimVerifierV2 is already whitelisted");
    } else {
      throw error;
    }
  }

  // Check if escrow needs to be added to verifier
  const isEscrow = await tossBankVerifierContract.isEscrow(escrowProxyAddress);
  if (!isEscrow) {
    console.log("Adding escrow to TossBankReclaimVerifierV2...");
    const tx3 = await tossBankVerifierContract.addEscrow(escrowProxyAddress);
    await tx3.wait();
    console.log("Escrow added to verifier");
  } else {
    console.log("Escrow is already added to TossBankReclaimVerifierV2");
  }

  // Log final deployment summary
  console.log("\n=== FINAL DEPLOYMENT SUMMARY ===");
  console.log("Escrow Proxy:", escrowProxyAddress);
  console.log("TossBankReclaimVerifierV2:", tossBankVerifierAddress);
  console.log("NullifierRegistry:", nullifierRegistryAddress);
  console.log("All contracts configured successfully!");
  console.log("=================================\n");
};

export default func;
func.tags = ["ConfigureContracts"];
// func.dependencies = ["NullifierRegistry", "EscrowUpgradeable", "TossBankReclaimVerifierV2"];
