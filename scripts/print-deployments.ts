import fs from "fs";
import path from "path";
import hre from "hardhat";

interface DeploymentInfo {
  address: string;
  abi: any[];
  transactionHash?: string;
  receipt?: any;
  args?: any[];
  linkedLibraries?: any;
  solcInputHash?: string;
  metadata?: string;
  bytecode?: string;
  deployedBytecode?: string;
  libraries?: any;
  facets?: any[];
  diamondCut?: any[];
  execute?: any;
  history?: any[];
  implementation?: string;
  devdoc?: any;
  userdoc?: any;
  storageLayout?: any;
}

async function printDeployments(networkName?: string): Promise<void> {
  const network = networkName || hre.network.name;
  const chainId = await hre.getChainId();
  
  console.log(`## Deployments - ${network.charAt(0).toUpperCase() + network.slice(1)} (Chain ID: ${chainId})\n`);

  // Get deployments directory path - hardhat-deploy uses network name by default
  const deploymentsDir = path.join(process.cwd(), "deployments", network);
  
  if (!fs.existsSync(deploymentsDir)) {
    console.log(`*No deployments found for network ${network}*\n`);
    console.log(`Expected directory: \`${deploymentsDir}\`\n`);
    return;
  }

  // Read all deployment files
  const files = fs.readdirSync(deploymentsDir);
  const deploymentFiles = files.filter(file => file.endsWith('.json') && file !== '.chainId');

  if (deploymentFiles.length === 0) {
    console.log(`*No deployment files found*\n`);
    return;
  }

  // Parse and display each deployment
  const deployments: { [name: string]: DeploymentInfo } = {};
  
  for (const file of deploymentFiles) {
    const contractName = file.replace('.json', '');
    const filePath = path.join(deploymentsDir, file);
    
    try {
      const deploymentData = JSON.parse(fs.readFileSync(filePath, 'utf8')) as DeploymentInfo;
      deployments[contractName] = deploymentData;
    } catch (error) {
      console.log(`❌ Error reading ${file}: ${error}`);
      continue;
    }
  }

  const contractAddresses = Object.entries(deployments).map(([name, deployment]) => ({
    name,
    address: deployment.address,
    isProxy: !!deployment.implementation,
    implementation: deployment.implementation,
    transactionHash: deployment.transactionHash
  }));

  // Markdown table output
  console.log("| Contracts | Address |");
  console.log("|-----------|---------|");
  
  const explorerUrls = getExplorerUrls(chainId);
  const explorerUrl = explorerUrls[0]; // Use first explorer URL
  
  contractAddresses.forEach(({ name, address }) => {
    const addressLink = explorerUrl ? `[${address}](${explorerUrl}/address/${address})` : address;
    console.log(`| ${name} | ${addressLink} |`);
  });
  
  console.log("");
}

function getExplorerUrls(chainId: string): string[] {
  const explorerMap: { [key: string]: string[] } = {
    "1": ["https://etherscan.io"],
    "8453": ["https://basescan.org"],
    "84532": ["https://base-sepolia.blockscout.com"],
    "1001": ["https://kairos.kaiascan.io"],
    "8217": ["https://kaiascan.io"],
    "11155111": ["https://sepolia.etherscan.io"],
    "17000": ["https://holesky.etherscan.io"],
  };
  
  return explorerMap[chainId] || [];
}

// Main execution
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const networkArg = args.find(arg => !arg.startsWith('--') && !arg.startsWith('-'));
  
  if (networkArg && networkArg !== hre.network.name) {
    console.log(`⚠️  Network argument provided (${networkArg}) but current network is ${hre.network.name}`);
    console.log(`   Showing deployments for current network: ${hre.network.name}`);
  }
  
  await printDeployments();
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error("❌ Error:", error);
    process.exit(1);
  });