// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/src/Script.sol";
import { TossBankReclaimVerifier } from "src/verifiers/TossBankReclaimVerifier.sol";
import { NullifierRegistry } from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { INullifierRegistry } from "src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import { ZkMinter } from "../src/ZkMinter.sol";
import { MockUSDT } from "../src/MockUSDT.sol";

contract DeployTestSetup is Script {
    TossBankReclaimVerifier public tossBankReclaimVerifier;
    NullifierRegistry public nullifierRegistry;
    ZkMinter public zkMinter;
    MockUSDT public usdt;

    string public constant PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";
    uint256 public timestampBuffer = 60;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockUSDT first
        usdt = new MockUSDT(deployer);
        console.log("MockUSDT deployed at:", address(usdt));

        // Deploy NullifierRegistry
        nullifierRegistry = new NullifierRegistry(deployer);
        console.log("NullifierRegistry deployed at:", address(nullifierRegistry));

        // Deploy ZkMinter
        zkMinter = new ZkMinter(deployer, address(usdt));
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

        // Setup - Set verifier data (same as in BaseTest.sol)
        address[] memory addresses = new address[](1);
        // TODO: create chain specific config
        addresses[0] = 0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E;
        bytes memory data = abi.encode(addresses);

        string memory bankAccount = vm.envString("BANK_ACCOUNT"); // unicode"1000-0000-0000(토스뱅크)"
        zkMinter.setVerifierData(address(tossBankReclaimVerifier), bankAccount, data);
        console.log("Set verifier data");

        // Setup - Add write permission to nullifier registry
        nullifierRegistry.addWritePermission(address(tossBankReclaimVerifier));
        console.log("Added write permission to nullifier registry");

        usdt.transferOwnership(address(zkMinter));
        console.log("Transferred ownership of MockUSDT to ZkMinter");
        vm.stopBroadcast();

        // Print summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("MockUSDT:", address(usdt));
        console.log("NullifierRegistry:", address(nullifierRegistry));
        console.log("ZkMinter:", address(zkMinter));
        console.log("TossBankReclaimVerifier:", address(tossBankReclaimVerifier));
        console.log("Owner/Deployer:", deployer);
    }
}
