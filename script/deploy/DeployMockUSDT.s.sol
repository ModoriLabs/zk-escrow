// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/MockUSDT.sol";
import "script/Base.s.sol";

contract DeployMockUSDT is BaseScript {
    function run() external {
        address prevMockUSDT = _getDeployedAddress("MockUSDT");
        if (prevMockUSDT != address(0)) {
            console.log("MockUSDT already deployed at:", prevMockUSDT);
            return;
        }

        vm.startBroadcast();
        address owner = broadcaster;
        MockUSDT mockUSDT = new MockUSDT(owner);
        console.log("MockUSDT deployed to:", address(mockUSDT));
        vm.stopBroadcast();

        _updateDeploymentFile("MockUSDT", address(mockUSDT));
    }
}
