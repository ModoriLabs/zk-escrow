// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "script/Base.s.sol";
import { TossBankReclaimVerifier } from "src/verifiers/TossBankReclaimVerifier.sol";
import { NullifierRegistry } from "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import { INullifierRegistry } from "src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import { ZkMinter } from "src/ZkMinter.sol";
import { IMintableERC20 } from "src/interfaces/IMintableERC20.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

contract DeployZkMinterScript is BaseScript {
    TossBankReclaimVerifier public tossBankReclaimVerifier;
    NullifierRegistry public nullifierRegistry;
    ZkMinter public zkMinter;

    string public constant PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";
    uint256 public timestampBuffer = 60;

    function setUp() public {}

    function run() public {
        address deployer = broadcaster;
        // Get USDT address from deployments file
        uint256 chainId = block.chainid;
        address krwAddress = _getDeployedAddress("KRW");

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Using KRW address:", krwAddress);

        vm.startBroadcast(broadcaster);

        // Check if NullifierRegistry already exists, otherwise deploy new one
        address existingNullifierRegistry = _getDeployedAddress("NullifierRegistry");

        if (existingNullifierRegistry != address(0)) {
            nullifierRegistry = NullifierRegistry(existingNullifierRegistry);
            console.log("Using existing NullifierRegistry at:", address(nullifierRegistry));
        } else {
            // Deploy new NullifierRegistry if not found
            nullifierRegistry = new NullifierRegistry(deployer);
            console.log("NullifierRegistry deployed at:", address(nullifierRegistry));

            // Update deployment file
            _updateDeploymentFile("NullifierRegistry", address(nullifierRegistry));
        }

        // Deploy ZkMinter
        zkMinter = new ZkMinter(deployer, krwAddress);
        console.log("ZkMinter deployed at:", address(zkMinter));

        // Update deployment file for ZkMinter
        _updateDeploymentFile("ZkMinter", address(zkMinter));

        // Deploy TossBankReclaimVerifier
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = PROVIDER_HASH;
        tossBankReclaimVerifier = new TossBankReclaimVerifier(
            deployer,
            address(zkMinter),
            INullifierRegistry(address(nullifierRegistry)),
            timestampBuffer,
            new bytes32[](0), // empty currencies
            providerHashes
        );
        console.log("TossBankReclaimVerifier deployed at:", address(tossBankReclaimVerifier));

        // Update deployment file for TossBankReclaimVerifier
        _updateDeploymentFile("TossBankReclaimVerifier", address(tossBankReclaimVerifier));

        // Setup - Add verifier to zkMinter
        zkMinter.addVerifier(address(tossBankReclaimVerifier));
        console.log("Added TossBankReclaimVerifier to ZkMinter");

        // Setup verifier data (same as in BaseTest.sol)
        address[] memory addresses = new address[](1);
        // TODO: create chain specific config
        addresses[0] = _getOwnerFromConfig(chainId);
        bytes memory data = abi.encode(addresses);

        string memory bankAccount = vm.envString("BANK_ACCOUNT"); // unicode"1000-0000-0000(토스뱅크)"
        zkMinter.setVerifierData(address(tossBankReclaimVerifier), bankAccount, data);
        console.log("Set verifier data for TossBankReclaimVerifier");

        // Give write permission to verifier
        nullifierRegistry.addWritePermission(address(tossBankReclaimVerifier));
        console.log("Added write permission to TossBankReclaimVerifier");

        // Grant MINTER_ROLE to ZkMinter (if the USDT contract supports role-based access)
        IAccessControl(krwAddress).grantRole(keccak256("MINTER_ROLE"), address(zkMinter));
        vm.stopBroadcast();

        // Log final addresses
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("KRW Address:", krwAddress);
        console.log("NullifierRegistry:", address(nullifierRegistry));
        console.log("ZkMinter:", address(zkMinter));
        console.log("TossBankReclaimVerifier:", address(tossBankReclaimVerifier));
        console.log("========================\n");
    }
}
