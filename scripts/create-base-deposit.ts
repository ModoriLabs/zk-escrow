import { ethers, deployments, network } from "hardhat";

async function main(): Promise<void> {
  console.log("Creating base deposit...");

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

  // Get TossBankReclaimVerifierV2
  const verifierDeployment = await deployments.get("TossBankReclaimVerifierV2");
  const verifierAddress = verifierDeployment.address;
  console.log("Using TossBankReclaimVerifierV2 at:", verifierAddress);

  const escrow = await ethers.getContractAt("EscrowUpgradeable", escrowAddress) as any;
  const usdt = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", usdtAddress) as any;

  // Parameters from your Foundry script
  const depositAmount = ethers.parseUnits("1", 6); // 100 USDC (6 decimals)
  const minIntentAmount = ethers.parseUnits("0.01", 6); // 0.01 USDC min
  const maxIntentAmount = ethers.parseUnits("1000", 6); // 1,000 USDC max per intent
  const bankAccount = "100202642943(토스뱅크)";
  const KRW_CONVERSION_RATE = ethers.parseUnits("1400", 18); // 1400 KRW per USDC
  const VERIFIER_ADDRESS_V2 = "0x2042c7E7A36CAB186189946ad751EAAe6769E661";

  console.log("Creating deposit with parameters:");
  console.log("- Deposit amount:", ethers.formatUnits(depositAmount, 6), "USDC");
  console.log("- Intent range:", ethers.formatUnits(minIntentAmount, 6), "-", ethers.formatUnits(maxIntentAmount, 6), "USDC");
  console.log("- Bank account:", bankAccount);
  console.log("- KRW conversion rate:", ethers.formatUnits(KRW_CONVERSION_RATE, 18), "KRW per USDC");

  try {
    // Check USDT balance
    const balance = await usdt.balanceOf(depositor.address);
    console.log("USDT balance:", ethers.formatUnits(balance, 6), "USDT");

    if (balance < depositAmount) {
      throw new Error("Insufficient USDT balance");
    }

    // Approve Escrow to spend USDT
    console.log("Approving USDT spending...");
    const approveTx = await usdt.connect(depositor).approve(escrowAddress, depositAmount);
    await approveTx.wait();
    console.log("USDT spending approved");

    // Prepare deposit parameters
    const intentRange = {
      min: minIntentAmount,
      max: maxIntentAmount
    };

    const verifiers = [verifierAddress];

    const witnessAddresses = [VERIFIER_ADDRESS_V2];
    const verifierData = [{
      payeeDetails: bankAccount,
      data: ethers.AbiCoder.defaultAbiCoder().encode(["address[]"], [witnessAddresses])
    }];

    const currencies = [[{
      code: ethers.keccak256(ethers.toUtf8Bytes("KRW")),
      conversionRate: KRW_CONVERSION_RATE
    }]];

    const tx = await escrow.connect(depositor).createDeposit(
      usdtAddress,
      depositAmount,
      intentRange,
      verifiers,
      verifierData,
      currencies
    );

    console.log("Transaction submitted:", tx.hash);
    console.log("Waiting for confirmation...");

    const receipt = await tx.wait();
    console.log("Transaction confirmed in block:", receipt?.blockNumber);

    // Parse logs to get the deposit ID
    const depositCreatedEvent = receipt?.logs?.find((log: any) => {
      try {
        const parsed = escrow.interface.parseLog({
          topics: log.topics,
          data: log.data
        });
        return parsed?.name === "DepositCreated";
      } catch {
        return false;
      }
    });

    if (depositCreatedEvent) {
      const parsed = escrow.interface.parseLog({
        topics: depositCreatedEvent.topics,
        data: depositCreatedEvent.data
      });
      const depositId = parsed?.args?.depositId;
      console.log("✅ Base deposit created successfully!");
      console.log("Deposit ID:", depositId?.toString());
      return depositId;
    } else {
      console.log("✅ Transaction successful, but couldn't parse deposit ID from logs");
    }

  } catch (error: any) {
    console.error("❌ Error creating deposit:", error.message);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
