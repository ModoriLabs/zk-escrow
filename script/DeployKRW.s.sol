// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/KRW.sol";
import {BaseScript} from "./Base.s.sol";
import {console} from "forge-std/src/console.sol";

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

        console.log("To verify this contract, run:");
        console.log("forge verify-contract", address(krw), "src/KRW.sol:KRW --chain-id", block.chainid, "--constructor-args", abi.encode(owner), "--etherscan-api-key $ETHERSCAN_API_KEY");
    }
}
