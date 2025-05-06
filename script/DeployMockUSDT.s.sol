// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/MockUSDT.sol";

contract DeployMockUSDT is Script {
    function run() external {
        vm.startBroadcast();
        MockUSDT mockUSDT = new MockUSDT();
        console.log("MockUSDT deployed to:", address(mockUSDT));
        vm.stopBroadcast();
    }
}
