// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/Escrow.sol";
import "script/Base.s.sol";

contract DeployEscrow is BaseScript {
    uint256 public constant INTENT_EXPIRATION_PERIOD = 1800; // 30 minutes

    function run() external {
        address prevEscrow = _getDeployedAddress("Escrow");
        if (prevEscrow != address(0)) {
            console.log("Escrow already deployed at:", prevEscrow);
            return; // Exit if already deployed
        }

        vm.startBroadcast();
        address owner = broadcaster;
        Escrow escrow = new Escrow(owner, INTENT_EXPIRATION_PERIOD);
        console.log("Escrow deployed to:", address(escrow));
        console.log("Owner:", owner);
        console.log("Intent expiration period:", INTENT_EXPIRATION_PERIOD);
        vm.stopBroadcast();

        _updateDeploymentFile("Escrow", address(escrow));

        // Save deployment info for verification
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Contract: Escrow");
        console.log("Address:", address(escrow));
        console.log("Owner:", owner);
        console.log("Constructor args:", owner, INTENT_EXPIRATION_PERIOD);
        console.log("========================\n");
    }
}