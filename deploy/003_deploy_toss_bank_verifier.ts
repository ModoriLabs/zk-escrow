import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const INTENT_EXPIRATION_PERIOD = 1800; // 30 minutes
const PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy, get, getOrNull } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("Deploying TossBankReclaimVerifierV2 on", network.name);
  console.log("Deployer:", deployer);

  // Get dependencies from previous deployments
  const nullifierRegistry = await get("NullifierRegistry");
  const escrow = await get("EscrowUpgradeable");

  const nullifierRegistryAddress = nullifierRegistry.address;
  const escrowProxyAddress = escrow.address;

  console.log("Using NullifierRegistry at:", nullifierRegistryAddress);
  console.log("Using Escrow at:", escrowProxyAddress);

  // Deploy or get TossBankReclaimVerifierV2
  let tossBankVerifierAddress: string;
  const existingTossBankVerifier = await getOrNull("TossBankReclaimVerifierV2");

  if (existingTossBankVerifier) {
    tossBankVerifierAddress = existingTossBankVerifier.address;
    console.log("Using existing TossBankReclaimVerifierV2 at:", tossBankVerifierAddress);
  } else {
    const providerHashes = [PROVIDER_HASH];
    const verifierCurrencies = [ethers.keccak256(ethers.toUtf8Bytes("KRW"))];

    const tossBankVerifier = await deploy("TossBankReclaimVerifierV2", {
      from: deployer,
      args: [
        deployer,
        escrowProxyAddress,
        nullifierRegistryAddress,
        INTENT_EXPIRATION_PERIOD,
        verifierCurrencies,
        providerHashes,
      ],
      log: true,
    });
    tossBankVerifierAddress = tossBankVerifier.address;
    console.log("TossBankReclaimVerifierV2 deployed at:", tossBankVerifierAddress);
  }

  console.log("TossBankReclaimVerifierV2 deployment completed at:", tossBankVerifierAddress);
};

export default func;
func.tags = ["TossBankReclaimVerifierV2"];
// func.dependencies = ["NullifierRegistry", "EscrowUpgradeable"];
