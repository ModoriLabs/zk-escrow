import { ethers, deployments, network } from "hardhat";

async function main(): Promise<void> {
  console.log("Increasing base deposit...");

  // Use specific private key for Kaia mainnet
  let depositor;
  const chainId = await network.provider.send("eth_chainId");

  if (chainId === "0x2019") { // Kaia mainnet (8217)
    const PROD_DEPOSITER_PRIVATE_KEY = process.env.PROD_DEPOSITER_PRIVATE_KEY;
    if (!PROD_DEPOSITER_PRIVATE_KEY) {
      throw new Error("PROD_DEPOSITER_PRIVATE_KEY environment variable required for Kaia mainnet");
    }
    depositor = new ethers.Wallet(PROD_DEPOSITER_PRIVATE_KEY, ethers.provider);
    console.log("Using PROD_DEPOSITER for Kaia mainnet:", depositor.address);
  } else {
    [depositor] = await ethers.getSigners();
    console.log("Using default signer:", depositor.address);
  }

  // Get deployed contracts from hardhat-deploy
  const escrowDeployment = await deployments.get("EscrowUpgradeable");
  const escrowAddress = escrowDeployment.address;
  console.log("Using EscrowUpgradeable at:", escrowAddress);

  // Get USDT token (you might need to deploy USDT for testing or get real USDC address)
  let usdtAddress: string;
  try {
    const usdtDeployment = await deployments.get("USDT");
    usdtAddress = usdtDeployment.address;
    console.log("Using USDT at:", usdtAddress);
  } catch {
    // Fallback to Base USDC address if USDT not deployed
    usdtAddress = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"; // Base USDC
    console.log("Using Base USDC at:", usdtAddress);
  }

  const escrow = await ethers.getContractAt("EscrowUpgradeable", escrowAddress) as any;
  const usdt = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", usdtAddress) as any;

  // Parameters - you can modify these as needed
  const depositId = process.env.DEPOSIT_ID ? parseInt(process.env.DEPOSIT_ID) : 1; // Default to deposit ID 1
  const increaseAmount = ethers.parseUnits(process.env.INCREASE_AMOUNT || "5", 6); // Default 5 USDC (6 decimals)

  console.log("Increasing deposit with parameters:");
  console.log("- Deposit ID:", depositId);
  console.log("- Increase amount:", ethers.formatUnits(increaseAmount, 6), "USDC");

  try {
    // Check USDT balance
    const balance = await usdt.balanceOf(depositor.address);
    console.log("USDT balance:", ethers.formatUnits(balance, 6), "USDT");

    if (balance < increaseAmount) {
      throw new Error("Insufficient USDT balance");
    }

    // Check if deposit exists
    const deposit = await escrow.deposits(depositId);
    if (deposit.depositor === ethers.ZeroAddress) {
      throw new Error(`Deposit ID ${depositId} does not exist`);
    }

    console.log("Current deposit amount:", ethers.formatUnits(deposit.amount, 6), "USDC");
    console.log("Deposit token:", deposit.token);

    // Approve Escrow to spend USDT
    console.log("Approving USDT spending...");
    const approveTx = await usdt.connect(depositor).approve(escrowAddress, increaseAmount);
    await approveTx.wait();
    console.log("USDT spending approved");

    // Call increaseDeposit
    const tx = await escrow.connect(depositor).increaseDeposit(depositId, increaseAmount);

    console.log("Transaction submitted:", tx.hash);
    console.log("Waiting for confirmation...");

    const receipt = await tx.wait();
    console.log("Transaction confirmed in block:", receipt?.blockNumber);

    // Get updated deposit amount
    const updatedDeposit = await escrow.deposits(depositId);
    console.log("✅ Deposit increased successfully!");
    console.log("New deposit amount:", ethers.formatUnits(updatedDeposit.amount, 6), "USDC");

  } catch (error: any) {
    console.error("❌ Error increasing deposit:", error.message);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
