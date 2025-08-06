// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "script/Base.s.sol";
import { TossBankReclaimVerifier } from "src/verifiers/TossBankReclaimVerifier.sol";
import { NullifierRegistry } from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { INullifierRegistry } from "src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import { ZkMinter } from "src/ZkMinter.sol";

/*
Usage Examples:

# Deploy TossBankReclaimVerifier and add to ZkMinter
forge script script/DeployTossBankReclaimVerifier.s.sol \
  --rpc-url holesky --broadcast --private-key $TESTNET_PRIVATE_KEY \
  --ffi

Note: Contract addresses are automatically loaded from deployments/{chainId}-deploy.json
Owner address is loaded from config.json
*/

contract DeployTossBankReclaimVerifier is BaseScript {
    // Provider hash from BaseTest.sol
    string public constant PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";

    function run() public broadcast {
        uint256 chainId = block.chainid;
        console.log("Chain ID:", chainId);
        console.log("Broadcaster:", broadcaster);

        // Load existing contract addresses using the generic function
        address zkMinterAddress = _getDeployedAddress("ZkMinter");
        address nullifierRegistryAddress = _getDeployedAddress("NullifierRegistry");

        console.log("=== DEPLOYING TOSSBANKRECLAIM VERIFIER ===");
        console.log("ZkMinter address:", zkMinterAddress);
        console.log("NullifierRegistry address:", nullifierRegistryAddress);

        // Get owner from config
        address owner = _getOwnerFromConfig(chainId);

        // Deploy TossBankReclaimVerifier
        uint256 timestampBuffer = 60;
        bytes32[] memory witnessAddresses = new bytes32[](0);
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = PROVIDER_HASH;

        TossBankReclaimVerifier tossBankVerifier = new TossBankReclaimVerifier(
            owner, // owner from config
            zkMinterAddress, // zkMinter
            INullifierRegistry(nullifierRegistryAddress), // nullifierRegistry
            timestampBuffer,
            witnessAddresses,
            providerHashes
        );

        console.log("TossBankReclaimVerifier deployed at:", address(tossBankVerifier));

        // Add verifier to ZkMinter
        ZkMinter zkMinter = ZkMinter(zkMinterAddress);
        zkMinter.addVerifier(address(tossBankVerifier));
        console.log("Added TossBankReclaimVerifier to ZkMinter");

        // Add write permission to nullifier registry
        NullifierRegistry nullifierRegistry = NullifierRegistry(nullifierRegistryAddress);
        nullifierRegistry.addWritePermission(address(tossBankVerifier));
        console.log("Added write permission to NullifierRegistry");

        // Update deployment file
        _updateDeploymentFile("TossBankReclaimVerifier", address(tossBankVerifier));

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("TossBankReclaimVerifier:", address(tossBankVerifier));
        console.log("Provider hashes:", providerHashes.length);
        console.log("Timestamp buffer:", timestampBuffer);
    }
}
