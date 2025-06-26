// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/src/Script.sol";
import { TossBankReclaimVerifier } from "src/verifiers/TossBankReclaimVerifier.sol";
import { NullifierRegistry } from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { INullifierRegistry } from "src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import { ZkMinter } from "src/ZkMinter.sol";
import { KRW } from "src/KRW.sol";

contract DeployTestSetup is Script {
    TossBankReclaimVerifier public tossBankReclaimVerifier;
    NullifierRegistry public nullifierRegistry;
    ZkMinter public zkMinter;
    KRW public krw;

    string public constant PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";
    uint256 public timestampBuffer = 60;
    address public constant VERIFIER_WALLET_ADDRESS = 0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy KRW first
        krw = new KRW(deployer);
        console.log("KRW deployed at:", address(krw));

        // Deploy NullifierRegistry
        nullifierRegistry = new NullifierRegistry(deployer);
        console.log("NullifierRegistry deployed at:", address(nullifierRegistry));

        // Deploy ZkMinter
        zkMinter = new ZkMinter(deployer, address(krw));
        console.log("ZkMinter deployed at:", address(zkMinter));

        // Deploy TossBankReclaimVerifier
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = PROVIDER_HASH;
        tossBankReclaimVerifier = new TossBankReclaimVerifier(
            deployer,
            address(zkMinter),
            INullifierRegistry(address(nullifierRegistry)),
            timestampBuffer,
            new bytes32[](0),
            providerHashes
        );
        console.log("TossBankReclaimVerifier deployed at:", address(tossBankReclaimVerifier));

        // Setup - Add verifier to zkMinter
        zkMinter.addVerifier(address(tossBankReclaimVerifier));
        console.log("Added verifier to zkMinter");

        // Setup - Set verifier data (matching BaseTest.sol pattern)
        address[] memory addresses = new address[](1);
        addresses[0] = VERIFIER_WALLET_ADDRESS;
        bytes memory data = abi.encode(addresses);

        // Use the exact bank account string from BaseTest.sol
        string memory bankAccount = vm.envString("BANK_ACCOUNT");
        zkMinter.setVerifierData(address(tossBankReclaimVerifier), bankAccount, data);
        console.log("Set verifier data with bank account: ", bankAccount);

        // Setup - Add write permission to nullifier registry
        nullifierRegistry.addWritePermission(address(tossBankReclaimVerifier));
        console.log("Added write permission to nullifier registry");

        // Grant MINTER_ROLE to ZkMinter on KRW token
        krw.grantRole(krw.MINTER_ROLE(), address(zkMinter));
        console.log("Granted MINTER_ROLE to ZkMinter on KRW");

        vm.stopBroadcast();

        // Print summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("KRW:", address(krw));
        console.log("NullifierRegistry:", address(nullifierRegistry));
        console.log("ZkMinter:", address(zkMinter));
        console.log("TossBankReclaimVerifier:", address(tossBankReclaimVerifier));
        console.log("Owner/Deployer:", deployer);
        console.log("Provider Hash:", PROVIDER_HASH);
        console.log("Verifier Wallet Address:", VERIFIER_WALLET_ADDRESS);
        console.log("Timestamp Buffer:", timestampBuffer, "seconds");
    }
}
