// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/src/Script.sol";
import { TossBankReclaimVerifier } from "src/verifiers/TossBankReclaimVerifier.sol";
import { NullifierRegistry } from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { ZkMinter, IZkMinter } from "../src/ZkMinter.sol";
import { KRW } from "../src/KRW.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InteractWithDeployedContracts is Script {
    // Deployed contract addresses from the deployment
    address constant KRW_TOKEN = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant NULLIFIER_REGISTRY = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address constant ZK_MINTER = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    address constant TOSS_BANK_VERIFIER = 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9;

    // Anvil default accounts
    address constant OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant ALICE = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address constant BOB = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address caller = vm.addr(privateKey);

        console.log("Caller address:", caller);
        console.log("Caller balance:", caller.balance);

        vm.startBroadcast(privateKey);

        // Get contract instances
        KRW krw = KRW(KRW_TOKEN);
        NullifierRegistry nullifierRegistry = NullifierRegistry(NULLIFIER_REGISTRY);
        ZkMinter zkMinter = ZkMinter(ZK_MINTER);
        TossBankReclaimVerifier verifier = TossBankReclaimVerifier(TOSS_BANK_VERIFIER);

        // Example interactions:

        // 1. Check KRW balance
        uint256 balance = krw.balanceOf(caller);
        console.log("KRW balance:", balance);

        // 2. Check if caller is a writer in nullifier registry
        bool isWriter = nullifierRegistry.isWriter(caller);
        console.log("Is writer in nullifier registry:", isWriter);

        // 3. Check if TossBankVerifier is a writer in nullifier registry
        bool verifierIsWriter = nullifierRegistry.isWriter(TOSS_BANK_VERIFIER);
        console.log("Is TossBankVerifier a writer:", verifierIsWriter);

        // 4. Get verifiers count in zkMinter
        address[] memory verifiers = getVerifiers(zkMinter);
        console.log("Number of verifiers:", verifiers.length);
        if (verifiers.length > 0) {
            console.log("First verifier:", verifiers[0]);
        }

        // 5. Check if ZkMinter has MINTER_ROLE on KRW
        bool hasMinterRole = krw.hasRole(krw.MINTER_ROLE(), ZK_MINTER);
        console.log("ZkMinter has MINTER_ROLE:", hasMinterRole);

        // 6. Signal an intent (example)
        if (caller == OWNER) {
            console.log("\n=== Signaling Intent ===");
            try zkMinter.signalIntent(ALICE, 1000 * 1e18, TOSS_BANK_VERIFIER) {
                console.log("Intent signaled successfully");

                // Check the intent
                uint256 intentId = zkMinter.accountIntent(ALICE);
                console.log("Intent ID for Alice:", intentId);

                if (intentId > 0) {
                    (address owner, address to, uint256 amount, uint256 timestamp, address verifier) = getIntent(zkMinter, intentId);
                    console.log("Intent owner:", owner);
                    console.log("Intent to:", to);
                    console.log("Intent amount:", amount);
                    console.log("Intent timestamp:", timestamp);
                    console.log("Intent verifier:", verifier);
                }
            } catch Error(string memory reason) {
                console.log("Failed to signal intent:", reason);
            }
        }

        // 7. Check verifier data
        console.log("\n=== Verifier Data ===");
        try zkMinter.verifierData(TOSS_BANK_VERIFIER) returns (string memory bankAccount, bytes memory witnessData) {
            console.log("Bank Account:", bankAccount);
            console.log("Witness Data Length:", witnessData.length);

            // Decode witness addresses
            if (witnessData.length > 0) {
                address[] memory witnesses = abi.decode(witnessData, (address[]));
                console.log("Number of witnesses:", witnesses.length);
                if (witnesses.length > 0) {
                    console.log("First witness:", witnesses[0]);
                }
            }
        } catch Error(string memory reason) {
            console.log("Failed to get verifier data:", reason);
        }

        vm.stopBroadcast();

        console.log("\n=== CONTRACT ADDRESSES ===");
        console.log("KRW:", KRW_TOKEN);
        console.log("NullifierRegistry:", NULLIFIER_REGISTRY);
        console.log("ZkMinter:", ZK_MINTER);
        console.log("TossBankReclaimVerifier:", TOSS_BANK_VERIFIER);
    }

    // Helper function to get verifiers (since it's an array)
    function getVerifiers(ZkMinter zkMinter) internal view returns (address[] memory) {
        // We need to call the verifiers array manually since there's no getter for the full array
        address[] memory verifiers = new address[](1);
        try zkMinter.verifiers(0) returns (address verifier) {
            verifiers[0] = verifier;
            return verifiers;
        } catch {
            address[] memory empty = new address[](0);
            return empty;
        }
    }

    // Helper function to get intent details
    function getIntent(ZkMinter zkMinter, uint256 intentId) internal view returns (address, address, uint256, uint256, address) {
        return zkMinter.intents(intentId);
    }
}
