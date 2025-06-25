// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Base.s.sol";
import { TossBankReclaimVerifier } from "../src/verifiers/TossBankReclaimVerifier.sol";
import { NullifierRegistry } from "../src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { INullifierRegistry } from "../src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import { ZkMinter } from "../src/ZkMinter.sol";
import { IMintableERC20 } from "../src/interfaces/IMintableERC20.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract DeployZkMinterScript is BaseScript {
    TossBankReclaimVerifier public tossBankReclaimVerifier;
    NullifierRegistry public nullifierRegistry;
    ZkMinter public zkMinter;

    uint256 public timestampBuffer = 60;

    function setUp() public {}

    function run() public {
        address deployer = broadcaster;
        // Get USDT address from deployments file
        uint256 chainId = 17000; // You can also get this from vm.envUint("CHAIN_ID") if needed
        address usdtAddress = _getDeployedAddress(chainId, "KORTProxy");

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Using USDT address:", usdtAddress);

        vm.startBroadcast(broadcaster);

        // Deploy NullifierRegistry
        nullifierRegistry = new NullifierRegistry(deployer);
        console.log("NullifierRegistry deployed at:", address(nullifierRegistry));

        // Deploy ZkMinter
        zkMinter = new ZkMinter(deployer, usdtAddress);
        console.log("ZkMinter deployed at:", address(zkMinter));

        // Deploy TossBankReclaimVerifier
        tossBankReclaimVerifier = new TossBankReclaimVerifier(
            deployer,
            address(zkMinter),
            INullifierRegistry(address(nullifierRegistry)),
            timestampBuffer,
            new bytes32[](0), // Empty provider hashes array
            new string[](0)   // Empty provider names array
        );
        console.log("TossBankReclaimVerifier deployed at:", address(tossBankReclaimVerifier));

        // Setup - Add verifier to zkMinter
        zkMinter.addVerifier(address(tossBankReclaimVerifier));
        console.log("Added TossBankReclaimVerifier to ZkMinter");

        // Setup verifier data (same as in BaseTest.sol)
        address[] memory addresses = new address[](1);
        // TODO: create chain specific config
        addresses[0] = 0x189027e3C77b3a92fd01bF7CC4E6a86E77F5034E;
        bytes memory data = abi.encode(addresses);

        string memory bankAccount = vm.envString("BANK_ACCOUNT"); // unicode"1000-0000-0000(토스뱅크)"
        zkMinter.setVerifierData(address(tossBankReclaimVerifier), bankAccount, data);
        console.log("Set verifier data for TossBankReclaimVerifier");

        // Give write permission to verifier
        nullifierRegistry.addWritePermission(address(tossBankReclaimVerifier));
        console.log("Added write permission to TossBankReclaimVerifier");

        // Grant MINTER_ROLE to ZkMinter (if the USDT contract supports role-based access)
        IAccessControl(usdtAddress).grantRole(keccak256("MINTER_ROLE"), address(zkMinter));
        vm.stopBroadcast();

        // Log final addresses
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("USDT Address:", usdtAddress);
        console.log("NullifierRegistry:", address(nullifierRegistry));
        console.log("ZkMinter:", address(zkMinter));
        console.log("TossBankReclaimVerifier:", address(tossBankReclaimVerifier));
        console.log("========================\n");
    }
}
