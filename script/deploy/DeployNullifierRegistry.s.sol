// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import "script/Base.s.sol";

contract DeployNullifierRegistry is BaseScript {
    function run() external {
        address prevRegistry = _getDeployedAddress("NullifierRegistry");
        if (prevRegistry != address(0)) {
            console.log("NullifierRegistry already deployed at:", prevRegistry);
            return; // Exit if already deployed
        }

        vm.startBroadcast();
        address owner = broadcaster;

        // Deploy NullifierRegistry
        NullifierRegistry nullifierRegistry = new NullifierRegistry(owner);

        console.log("NullifierRegistry deployed to:", address(nullifierRegistry));
        console.log("Owner:", owner);

        vm.stopBroadcast();

        // Only update deployment file if actually broadcasting
        _updateDeploymentFile("NullifierRegistry", address(nullifierRegistry));

        // Save deployment info for verification
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Contract: NullifierRegistry");
        console.log("Address:", address(nullifierRegistry));
        console.log("Owner:", owner);
        console.log("========================\n");
    }
}
