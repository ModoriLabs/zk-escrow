// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/MockUSDT.sol";
import {BaseScript} from "./Base.s.sol";

contract DeployMockUSDT is BaseScript {
    function run() external {
        vm.startBroadcast();
        MockUSDT mockUSDT = new MockUSDT();
        console.log("MockUSDT deployed to:", address(mockUSDT));
        vm.stopBroadcast();
    }
}
