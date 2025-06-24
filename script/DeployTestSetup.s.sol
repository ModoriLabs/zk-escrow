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

    uint256 public timestampBuffer = 60;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockUSDT first
        usdt = new MockUSDT();
        console.log("MockUSDT deployed at:", address(usdt));

        // Deploy NullifierRegistry
        nullifierRegistry = new NullifierRegistry(deployer);
        console.log("NullifierRegistry deployed at:", address(nullifierRegistry));

        // Deploy ZkMinter
        zkMinter = new ZkMinter(deployer, address(usdt));
        console.log("ZkMinter deployed at:", address(zkMinter));

        // Deploy TossBankReclaimVerifier
        tossBankReclaimVerifier = new TossBankReclaimVerifier(
            deployer,
            address(zkMinter),
            INullifierRegistry(address(nullifierRegistry)),
            timestampBuffer,
            new bytes32[](0),
            new string[](0)
        );
        console.log("TossBankReclaimVerifier deployed at:", address(tossBankReclaimVerifier));

        // Setup - Add verifier to zkMinter
        zkMinter.addVerifier(address(tossBankReclaimVerifier));
        console.log("Added verifier to zkMinter");

        // Setup - Set verifier data (same as in BaseTest.sol)
        bytes memory data = new bytes(96); // 3 * 32 bytes
        assembly {
            mstore(add(data, 0x20), 0x20)                                    // offset
            mstore(add(data, 0x40), 0x01)                                    // length
            mstore(add(data, 0x60), 0x189027e3c77b3a92fd01bf7cc4e6a86e77f5034e) // address
        }
        zkMinter.setVerifierData(address(tossBankReclaimVerifier), "", data);
        console.log("Set verifier data");

        // Setup - Add write permission to nullifier registry
        nullifierRegistry.addWritePermission(address(tossBankReclaimVerifier));
        console.log("Added write permission to nullifier registry");

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
