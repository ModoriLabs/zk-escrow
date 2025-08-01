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
import { BaseScript } from "../Base.s.sol";

contract DeployEscrowTestSetup is BaseScript {
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

    function run() external {
        // Use PRIVATE_KEY env var, or default to first Anvil account
        // 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        uint256 deployerPrivateKey = vm.envOr("ANVIL_DEPLOYER_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MockUSDT
        usdt = new MockUSDT(deployer);
        console.log("MockUSDT deployed at:", address(usdt));
        _updateDeploymentFile("MockUSDT", address(usdt));

        // 2. Deploy NullifierRegistry
        nullifierRegistry = new NullifierRegistry(deployer);
        console.log("NullifierRegistry deployed at:", address(nullifierRegistry));
        _updateDeploymentFile("NullifierRegistry", address(nullifierRegistry));

        // 3. Deploy Escrow
        escrow = new Escrow(deployer, INTENT_EXPIRATION_PERIOD, CHAIN_NAME);
        console.log("Escrow deployed at:", address(escrow));
        _updateDeploymentFile("Escrow", address(escrow));

        // 4. Deploy TossBankReclaimVerifierV2
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = PROVIDER_HASH;

        bytes32[] memory verifierCurrencies = new bytes32[](1);
        verifierCurrencies[0] = keccak256("KRW");

        tossBankReclaimVerifier = new TossBankReclaimVerifierV2(
            deployer,
            address(escrow),
            INullifierRegistry(address(nullifierRegistry)),
            timestampBuffer,
            verifierCurrencies,
            providerHashes
        );
        console.log("TossBankReclaimVerifierV2 deployed at:", address(tossBankReclaimVerifier));
        _updateDeploymentFile("TossBankReclaimVerifierV2", address(tossBankReclaimVerifier));

        // 5. Setup permissions and configurations

        // Add write permission to nullifier registry
        nullifierRegistry.addWritePermission(address(tossBankReclaimVerifier));
        console.log("Added write permission to nullifier registry");

        // Whitelist the verifier in escrow
        escrow.addWhitelistedPaymentVerifier(address(tossBankReclaimVerifier));
        console.log("Whitelisted TossBankReclaimVerifierV2 in Escrow");
        vm.stopBroadcast();

        // Print summary
        printDeploymentSummary();
    }

    function printDeploymentSummary() internal view {
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MockUSDT:", address(usdt));
        console.log("NullifierRegistry:", address(nullifierRegistry));
        console.log("Escrow:", address(escrow));
        console.log("TossBankReclaimVerifierV2:", address(tossBankReclaimVerifier));
        console.log("Owner/Deployer:", escrow.owner());
        console.log("\n=== CONFIGURATION ===");
        console.log("Intent Expiration Period:", INTENT_EXPIRATION_PERIOD, "seconds");
        console.log("Provider Hash:", PROVIDER_HASH);
        console.log("Verifier Wallet Address:", VERIFIER_WALLET_ADDRESS);
        console.log("Timestamp Buffer:", timestampBuffer, "seconds");
        console.log("=========================\n");
    }
}
