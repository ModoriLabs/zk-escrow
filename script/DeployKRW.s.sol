// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/KRW.sol";
import "./Base.s.sol";

contract DeployKRW is BaseScript {
    function run() external {
        vm.startBroadcast();
        address owner = broadcaster;
        KRW krw = new KRW(owner);
        console.log("KRW deployed to:", address(krw));
        console.log("Initial supply:", krw.totalSupply());
        console.log("Owner:", owner);
        console.log("Owner balance:", krw.balanceOf(owner));
        vm.stopBroadcast();

        // Save deployment info for verification
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Contract: KRW");
        console.log("Address:", address(krw));
        console.log("Owner:", owner);
        console.log("Constructor args:", owner);
        console.log("========================\n");
    }
}
