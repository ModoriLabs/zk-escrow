// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EscrowUpgradeable} from "src/EscrowUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "script/Base.s.sol";

contract UpgradeEscrow is BaseScript {
    EscrowUpgradeable public escrowProxy;
    EscrowUpgradeable public newImplementation;

    function run() external {
        vm.startBroadcast();
        
        // Get the existing proxy address
        address proxyAddress = _getDeployedAddress("EscrowProxy");
        require(proxyAddress != address(0), "Escrow proxy not found");
        
        escrowProxy = EscrowUpgradeable(proxyAddress);
        console.log("Current Escrow proxy at:", proxyAddress);
        
        // Deploy new implementation
        newImplementation = new EscrowUpgradeable();
        console.log("New implementation deployed at:", address(newImplementation));
        
        // Upgrade the proxy to the new implementation
        escrowProxy.upgradeToAndCall(address(newImplementation), "");
        console.log("Proxy upgraded to new implementation");
        
        // Update deployment file
        _updateDeploymentFile("EscrowImplementation", address(newImplementation));
        
        vm.stopBroadcast();
        
        console.log("\n=== UPGRADE SUMMARY ===");
        console.log("Proxy address:", address(escrowProxy));
        console.log("New implementation:", address(newImplementation));
        console.log("=====================\n");
    }
}