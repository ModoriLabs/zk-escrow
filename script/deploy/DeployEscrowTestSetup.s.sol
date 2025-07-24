// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/src/Script.sol";
import { Escrow } from "src/Escrow.sol";
import { IEscrow } from "src/interfaces/IEscrow.sol";
import { TossBankReclaimVerifierV2 } from "src/verifiers/TossBankReclaimVerifierV2.sol";
import { NullifierRegistry } from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { INullifierRegistry } from "src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import { MockUSDT } from "src/MockUSDT.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployEscrowTestSetup is Script {
    // Contract instances
    Escrow public escrow;
    TossBankReclaimVerifierV2 public tossBankReclaimVerifier;
    NullifierRegistry public nullifierRegistry;
    MockUSDT public usdt;

    // Constants
    uint256 public constant INTENT_EXPIRATION_PERIOD = 1800; // 30 minutes
    string public constant PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";
    uint256 public timestampBuffer = 60;
    address public constant VERIFIER_WALLET_ADDRESS = 0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E;
    string public constant CHAIN_NAME = "anvil";

    // Test accounts
    address public alice;
    address public bob;
    address public charlie;

    function run() external {
        // Use PRIVATE_KEY env var, or default to first Anvil account
        // 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        uint256 deployerPrivateKey = vm.envOr("ANVIL_DEPLOYER_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        // Create test accounts
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MockUSDT
        usdt = new MockUSDT(deployer);
        console.log("MockUSDT deployed at:", address(usdt));

        // 2. Deploy NullifierRegistry
        nullifierRegistry = new NullifierRegistry(deployer);
        console.log("NullifierRegistry deployed at:", address(nullifierRegistry));

        // 3. Deploy Escrow
        escrow = new Escrow(deployer, INTENT_EXPIRATION_PERIOD, CHAIN_NAME);
        console.log("Escrow deployed at:", address(escrow));

        // 4. Deploy TossBankReclaimVerifierV2
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = PROVIDER_HASH;

        bytes32[] memory verifierCurrencies = new bytes32[](2);
        verifierCurrencies[0] = keccak256("USD");
        verifierCurrencies[1] = keccak256("KRW");

        tossBankReclaimVerifier = new TossBankReclaimVerifierV2(
            deployer,
            address(escrow),
            INullifierRegistry(address(nullifierRegistry)),
            timestampBuffer,
            verifierCurrencies,
            providerHashes
        );
        console.log("TossBankReclaimVerifierV2 deployed at:", address(tossBankReclaimVerifier));

        // 5. Setup permissions and configurations

        // Add write permission to nullifier registry
        nullifierRegistry.addWritePermission(address(tossBankReclaimVerifier));
        console.log("Added write permission to nullifier registry");

        // Whitelist the verifier in escrow
        escrow.addWhitelistedPaymentVerifier(address(tossBankReclaimVerifier));
        console.log("Whitelisted TossBankReclaimVerifierV2 in Escrow");

        // 6. Mint test USDT to test accounts
        uint256 aliceAmount = 100000e6; // 100,000 USDT
        uint256 bobAmount = 50000e6;    // 50,000 USDT
        uint256 charlieAmount = 30000e6; // 30,000 USDT

        usdt.mint(alice, aliceAmount);
        usdt.mint(bob, bobAmount);
        usdt.mint(charlie, charlieAmount);
        console.log("Minted USDT to test accounts");

        vm.stopBroadcast();

        // Note: Sample deposit creation removed as it requires alice to have ETH for gas
        console.log("\nNote: To create a sample deposit, alice needs ETH for gas.");

        // Print summary
        printDeploymentSummary();
    }

    function createSampleDeposit() internal {
        console.log("\nCreating sample deposit...");

        uint256 depositAmount = 10000e6; // 10,000 USDT

        // Setup intent range
        IEscrow.Range memory intentRange = IEscrow.Range({
            min: 100e6,  // Min 100 USDT
            max: 2000e6  // Max 2,000 USDT
        });

        // Setup verifiers
        address[] memory verifiers = new address[](1);
        verifiers[0] = address(tossBankReclaimVerifier);

        // Setup verifier data
        address[] memory witnesses = new address[](1);
        witnesses[0] = VERIFIER_WALLET_ADDRESS;

        IEscrow.DepositVerifierData[] memory verifierData = new IEscrow.DepositVerifierData[](1);
        verifierData[0] = IEscrow.DepositVerifierData({
            payeeDetails: unicode"100202642943(토스뱅크)",
            data: abi.encode(witnesses)
        });

        // Setup currencies with conversion rates
        uint256 usdToKrwRate = 1380 * 1e18; // 1 USD = 1380 KRW
        IEscrow.Currency[][] memory currencies = new IEscrow.Currency[][](1);
        currencies[0] = new IEscrow.Currency[](2);
        currencies[0][0] = IEscrow.Currency({
            code: keccak256("USD"),
            conversionRate: 1e18 // Base rate
        });
        currencies[0][1] = IEscrow.Currency({
            code: keccak256("KRW"),
            conversionRate: usdToKrwRate
        });

        // Alice approves and creates deposit
        vm.stopBroadcast();
        vm.startPrank(alice);
        usdt.approve(address(escrow), depositAmount);
        vm.stopPrank();
        vm.startBroadcast();

        // Use alice as the sender for the deposit
        vm.stopBroadcast();
        vm.startPrank(alice);
        uint256 depositId = escrow.createDeposit(
            IERC20(address(usdt)),
            depositAmount,
            intentRange,
            verifiers,
            verifierData,
            currencies
        );
        vm.stopPrank();
        vm.startBroadcast();

        console.log("Created deposit with ID:", depositId);
        console.log("Deposit amount:", depositAmount);
        console.log("From account:", alice);
    }

    function printDeploymentSummary() internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MockUSDT:", address(usdt));
        console.log("NullifierRegistry:", address(nullifierRegistry));
        console.log("Escrow:", address(escrow));
        console.log("TossBankReclaimVerifierV2:", address(tossBankReclaimVerifier));
        console.log("Owner/Deployer:", escrow.owner());
        console.log("\n=== TEST ACCOUNTS ===");
        // console.log("Alice:", alice, "Balance:", usdt.balanceOf(alice), "USDT");
        // console.log("Bob:", bob, "Balance:", usdt.balanceOf(bob), "USDT");
        // console.log("Charlie:", charlie, "Balance:", usdt.balanceOf(charlie), "USDT");
        console.log("\n=== CONFIGURATION ===");
        console.log("Intent Expiration Period:", INTENT_EXPIRATION_PERIOD, "seconds");
        console.log("Provider Hash:", PROVIDER_HASH);
        console.log("Verifier Wallet Address:", VERIFIER_WALLET_ADDRESS);
        console.log("Timestamp Buffer:", timestampBuffer, "seconds");
        console.log("=========================\n");
    }
}
