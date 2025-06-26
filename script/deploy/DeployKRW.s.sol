// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/KRW.sol";
import "script/Base.s.sol";

contract DeployKRW is BaseScript {
    function run() external {
        address prevKRW = _getDeployedAddress(block.chainid, "KRW");
        if (prevKRW != address(0)) {
            console.log("KRW already deployed at:", prevKRW);
            return; // Exit if already deployed
        }

        vm.startBroadcast();
        address owner = broadcaster;
        KRW krw = new KRW(owner);
        console.log("KRW deployed to:", address(krw));
        console.log("Initial supply:", krw.totalSupply());
        console.log("Owner:", owner);
        console.log("Owner balance:", krw.balanceOf(owner));
        vm.stopBroadcast();

        _updateDeploymentFile("KRW", address(krw));

        // Save deployment info for verification
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Contract: KRW");
        console.log("Address:", address(krw));
        console.log("Owner:", owner);
        console.log("Constructor args:", owner);
        console.log("========================\n");
    }
}
