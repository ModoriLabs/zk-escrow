import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

async function getSigner(hre: HardhatRuntimeEnvironment) {
  const chainId = await hre.network.provider.send("eth_chainId");

  if (chainId === "0x2019") { // Kaia mainnet (8217)
    const PROD_DEPOSITER_PRIVATE_KEY = process.env.PROD_DEPOSITER_PRIVATE_KEY;
    if (!PROD_DEPOSITER_PRIVATE_KEY) {
      throw new Error("PROD_DEPOSITER_PRIVATE_KEY environment variable required for Kaia mainnet");
    }
    const signer = new hre.ethers.Wallet(PROD_DEPOSITER_PRIVATE_KEY, hre.ethers.provider);
    console.log("Using PROD_DEPOSITER for Kaia mainnet:", signer.address);
    return signer;
  } else {
    const [signer] = await hre.ethers.getSigners();
    console.log("Using default signer:", signer.address);
    return signer;
  }
}

async function getEscrowContract(hre: HardhatRuntimeEnvironment) {
  const escrowDeployment = await hre.deployments.get("EscrowUpgradeable");
  const escrowAddress = escrowDeployment.address;
  console.log("Using EscrowUpgradeable at:", escrowAddress);
  const escrow = await hre.ethers.getContractAt("EscrowUpgradeable", escrowAddress) as any;
  return { escrow, escrowAddress };
}

async function getVerifier(hre: HardhatRuntimeEnvironment, verifierAddress?: string) {
  if (verifierAddress) {
    console.log("Using custom verifier:", verifierAddress);
    return verifierAddress;
  }
  
  try {
    const verifierDeployment = await hre.deployments.get("TossBankReclaimVerifierV2");
    const verifier = verifierDeployment.address;
    console.log("Using TossBankReclaimVerifierV2 at:", verifier);
    return verifier;
  } catch {
    throw new Error("No verifier address found. Please provide --verifier or deploy TossBankReclaimVerifierV2");
  }
}

async function validateDeposit(escrow: any, depositId: number, hre: HardhatRuntimeEnvironment) {
  const deposit = await escrow.deposits(depositId);
  if (deposit.depositor === hre.ethers.ZeroAddress) {
    throw new Error(`Deposit ID ${depositId} does not exist`);
  }
  
  console.log("Deposit found:");
  console.log("- Depositor:", deposit.depositor);
  console.log("- Amount:", hre.ethers.formatUnits(deposit.amount, 6), "USDC");
  
  return deposit;
}

task("escrow:increase-deposit", "Increase an existing deposit")
  .addParam("depositId", "The deposit ID", "1")
  .addParam("amount", "The amount to increase (in USDC)", "5")
  .addFlag("dryRun", "Simulate the transaction without executing")
  .setAction(async (taskArgs, hre) => {
    console.log("Increasing base deposit...");

    const depositor = await getSigner(hre);
    const { escrow, escrowAddress } = await getEscrowContract(hre);

    // Get USDT token address
    let usdtAddress: string;
    const usdtDeployment = await hre.deployments.get("USDT");
    usdtAddress = usdtDeployment.address;
    console.log("Using USDT at:", usdtAddress);

    const usdt = await hre.ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", usdtAddress) as any;

    // Parameters
    const depositId = parseInt(taskArgs.depositId);
    const increaseAmount = hre.ethers.parseUnits(taskArgs.amount, 6);

    console.log("Increasing deposit with parameters:");
    console.log("- Deposit ID:", depositId);
    console.log("- Increase amount:", hre.ethers.formatUnits(increaseAmount, 6), "USDC");

    try {
      // Check USDT balance
      const balance = await usdt.balanceOf(depositor.address);
      console.log("USDT balance:", hre.ethers.formatUnits(balance, 6), "USDT");

      if (balance < increaseAmount) {
        throw new Error("Insufficient USDT balance");
      }

      // Validate deposit exists
      const deposit = await validateDeposit(escrow, depositId, hre);
      console.log("Current deposit amount:", hre.ethers.formatUnits(deposit.amount, 6), "USDC");

      if (taskArgs.dryRun) {
        console.log("\n🔍 DRY RUN MODE - No transaction will be executed");
        console.log("Would approve USDT spending:", hre.ethers.formatUnits(increaseAmount, 6), "USDT");
        console.log("Would increase deposit ID", depositId, "by", hre.ethers.formatUnits(increaseAmount, 6), "USDC");
        console.log("Expected new deposit amount:", hre.ethers.formatUnits(deposit.amount + increaseAmount, 6), "USDC");
        console.log("✅ Dry run completed successfully!");
      } else {
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
        console.log("New deposit amount:", hre.ethers.formatUnits(updatedDeposit.amount, 6), "USDC");
      }

    } catch (error: any) {
      console.error("❌ Error increasing deposit:", error.message);
      throw error;
    }
  });

task("escrow:update-conversion-rate", "Update deposit conversion rate")
  .addParam("depositId", "The deposit ID", "1")
  .addParam("rate", "The conversion rate", "1350")
  .addOptionalParam("verifier", "Verifier address")
  .addOptionalParam("currency", "Currency code", "KRW")
  .addFlag("dryRun", "Simulate the transaction without executing")
  .setAction(async (taskArgs, hre) => {
    console.log("Updating deposit conversion rate...");

    const signer = await getSigner(hre);
    const { escrow } = await getEscrowContract(hre);

    // Parameters
    const depositId = parseInt(taskArgs.depositId);
    const conversionRate = BigInt(taskArgs.rate);
    const currencyCode = taskArgs.currency;

    // Get verifier
    const verifier = await getVerifier(hre, taskArgs.verifier);
    const currency = hre.ethers.keccak256(hre.ethers.toUtf8Bytes(currencyCode));

    console.log("Updating conversion rate with parameters:");
    console.log("- Deposit ID:", depositId);
    console.log("- Verifier:", verifier);
    console.log("- Currency:", currencyCode, "(hash:", currency, ")");
    console.log("- New conversion rate:", conversionRate.toString());

    try {
      // Validate deposit exists
      await validateDeposit(escrow, depositId, hre);

      // Get current conversion rate
      const currentRate = await escrow.depositCurrencyConversionRate(depositId, verifier, currency);
      console.log("Current conversion rate:", currentRate.toString());

      if (currentRate === conversionRate) {
        console.log("⚠️  Conversion rate is already set to the specified value");
        return;
      }

      if (taskArgs.dryRun) {
        console.log("\n🔍 DRY RUN MODE - No transaction will be executed");
        console.log("Would update conversion rate for deposit ID", depositId);
        console.log("From:", currentRate.toString());
        console.log("To:", conversionRate.toString());
        console.log("✅ Dry run completed successfully!");
      } else {
        // Update conversion rate
        const tx = await escrow.connect(signer).updateDepositConversionRate(
          depositId,
          verifier,
          currency,
          conversionRate
        );

        console.log("Transaction submitted:", tx.hash);
        console.log("Waiting for confirmation...");

        const receipt = await tx.wait();
        console.log("Transaction confirmed in block:", receipt?.blockNumber);

        // Verify the update
        const newRate = await escrow.depositCurrencyConversionRate(depositId, verifier, currency);
        console.log("✅ Conversion rate updated successfully!");
        console.log("New conversion rate:", newRate.toString());
      }

    } catch (error: any) {
      console.error("❌ Error updating conversion rate:", error.message);
      throw error;
    }
  });

task("escrow:update-intent-range", "Update deposit intent amount range")
  .addParam("depositId", "The deposit ID", "1")
  .addParam("min", "Minimum amount in USDC (with decimals)", "100")
  .addParam("max", "Maximum amount in USDC (with decimals)", "10000")
  .addFlag("dryRun", "Simulate the transaction without executing")
  .setAction(async (taskArgs, hre) => {
    console.log("Updating deposit intent amount range...");

    const signer = await getSigner(hre);
    const { escrow } = await getEscrowContract(hre);

    // Parameters - amounts are in USDC with 6 decimals
    const depositId = parseInt(taskArgs.depositId);
    const minAmount = hre.ethers.parseUnits(taskArgs.min, 6);
    const maxAmount = hre.ethers.parseUnits(taskArgs.max, 6);

    console.log("Updating deposit intent amount range with parameters:");
    console.log("- Deposit ID:", depositId);
    console.log("- Min amount:", hre.ethers.formatUnits(minAmount, 6), "USDC");
    console.log("- Max amount:", hre.ethers.formatUnits(maxAmount, 6), "USDC");

    try {
      // Validate deposit exists and get current deposit info
      const deposit = await validateDeposit(escrow, depositId, hre);

      // Get current range from the deposit struct
      const currentRange = deposit.intentAmountRange;
      console.log("Current range:");
      console.log("- Min:", hre.ethers.formatUnits(currentRange.min, 6), "USDC");
      console.log("- Max:", hre.ethers.formatUnits(currentRange.max, 6), "USDC");

      if (currentRange.min === minAmount && currentRange.max === maxAmount) {
        console.log("⚠️  Intent amount range is already set to the specified values");
        return;
      }

      // Validate the new range
      if (minAmount === 0n || minAmount > maxAmount || maxAmount > deposit.amount) {
        throw new Error(`Invalid range: min must be > 0, min <= max, and max <= deposit amount (${hre.ethers.formatUnits(deposit.amount, 6)} USDC)`);
      }

      if (taskArgs.dryRun) {
        console.log("\n🔍 DRY RUN MODE - No transaction will be executed");
        console.log("Would update intent amount range for deposit ID", depositId);
        console.log("From range:");
        console.log("  Min:", hre.ethers.formatUnits(currentRange.min, 6), "USDC");
        console.log("  Max:", hre.ethers.formatUnits(currentRange.max, 6), "USDC");
        console.log("To range:");
        console.log("  Min:", hre.ethers.formatUnits(minAmount, 6), "USDC");
        console.log("  Max:", hre.ethers.formatUnits(maxAmount, 6), "USDC");
        console.log("✅ Dry run completed successfully!");
      } else {
        // Update intent amount range - function only takes depositId, min, max
        const tx = await escrow.connect(signer).updateDepositIntentAmountRange(
          depositId,
          minAmount,
          maxAmount
        );

        console.log("Transaction submitted:", tx.hash);
        console.log("Waiting for confirmation...");

        const receipt = await tx.wait();
        console.log("Transaction confirmed in block:", receipt?.blockNumber);

        // Verify the update by fetching the deposit again
        const updatedDeposit = await escrow.deposits(depositId);
        const newRange = updatedDeposit.intentAmountRange;
        console.log("✅ Deposit intent amount range updated successfully!");
        console.log("New range:");
        console.log("- Min:", hre.ethers.formatUnits(newRange.min, 6), "USDC");
        console.log("- Max:", hre.ethers.formatUnits(newRange.max, 6), "USDC");
      }

    } catch (error: any) {
      console.error("❌ Error updating deposit intent amount range:", error.message);
      throw error;
    }
  });