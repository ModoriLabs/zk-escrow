// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Base.s.sol";

/*
Usage Examples:

# Verify all contracts on Holesky
forge script script/VerifyContracts.s.sol --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY --sig "verifyAll()" --etherscan-api-key $ETHERSCAN_API_KEY

# Verify specific contract
forge script script/VerifyContracts.s.sol --rpc-url holesky --private-key $TESTNET_PRIVATE_KEY --sig "verifyKRW()" --etherscan-api-key $ETHERSCAN_API_KEY

Note: Contract addresses are automatically loaded from deployments/{chainId}-deploy.json
*/

contract VerifyContracts is BaseScript {

    struct DeployedContracts {
        address krw;
        address nullifierRegistry;
        address zkMinter;
        address tossBankReclaimVerifier;
    }

    function verifyAll() public {
        DeployedContracts memory contracts = _loadDeployedContracts();

        console.log("=== VERIFYING ALL CONTRACTS ===");

        _verifyKRW(contracts.krw);
        _verifyNullifierRegistry(contracts.nullifierRegistry);
        _verifyZkMinter(contracts.zkMinter, contracts.krw);
        _verifyTossBankReclaimVerifier(contracts.tossBankReclaimVerifier, contracts.zkMinter, contracts.nullifierRegistry);

        console.log("=== VERIFICATION COMPLETE ===");
    }

    function verifyKRW() public {
        DeployedContracts memory contracts = _loadDeployedContracts();
        _verifyKRW(contracts.krw);
    }

    function verifyNullifierRegistry() public {
        DeployedContracts memory contracts = _loadDeployedContracts();
        _verifyNullifierRegistry(contracts.nullifierRegistry);
    }

    function verifyZkMinter() public {
        DeployedContracts memory contracts = _loadDeployedContracts();
        _verifyZkMinter(contracts.zkMinter, contracts.krw);
    }

    function verifyTossBankReclaimVerifier() public {
        DeployedContracts memory contracts = _loadDeployedContracts();
        _verifyTossBankReclaimVerifier(contracts.tossBankReclaimVerifier, contracts.zkMinter, contracts.nullifierRegistry);
    }

    function _loadDeployedContracts() internal view returns (DeployedContracts memory contracts) {
        uint256 chainId = block.chainid;
        console.log("Loading contracts for chain ID:", chainId);

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", vm.toString(chainId), deploymentFileSuffix);

        console.log("Reading deployment file:", path);

        try vm.readFile(path) returns (string memory json) {
            contracts.krw = vm.parseJsonAddress(json, ".KRW");
            contracts.nullifierRegistry = vm.parseJsonAddress(json, ".NullifierRegistry");
            contracts.zkMinter = vm.parseJsonAddress(json, ".ZkMinter");
            contracts.tossBankReclaimVerifier = vm.parseJsonAddress(json, ".TossBankReclaimVerifier");

            console.log("Loaded addresses:");
            console.log("  KRW:", contracts.krw);
            console.log("  NullifierRegistry:", contracts.nullifierRegistry);
            console.log("  ZkMinter:", contracts.zkMinter);
            console.log("  TossBankReclaimVerifier:", contracts.tossBankReclaimVerifier);

            // Validate addresses
            require(contracts.krw != address(0), "KRW address not found");
            require(contracts.nullifierRegistry != address(0), "NullifierRegistry address not found");
            require(contracts.zkMinter != address(0), "ZkMinter address not found");
            require(contracts.tossBankReclaimVerifier != address(0), "TossBankReclaimVerifier address not found");

        } catch {
            revert(string.concat("Failed to read deployment file: ", path));
        }
    }

    function _verifyKRW(address krwAddress) internal {
        console.log("Verifying KRW at:", krwAddress);

        // Constructor args: address _admin
        address admin = broadcaster; // Assuming deployer is admin
        bytes memory constructorArgs = abi.encode(admin);

        string memory etherscanApiKey = vm.envString("ETHERSCAN_API_KEY");

        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(krwAddress);
        cmd[3] = "src/KRW.sol:KRW";
        cmd[4] = "--chain-id";
        cmd[5] = vm.toString(block.chainid);
        cmd[6] = "--constructor-args";
        cmd[7] = vm.toString(constructorArgs);
        cmd[8] = string.concat("--etherscan-api-key=", etherscanApiKey);

        console.log("Executing: forge verify-contract", vm.toString(krwAddress), "src/KRW.sol:KRW");

        try vm.ffi(cmd) returns (bytes memory result) {
            console.log("KRW verification result:", string(result));
            console.log("KRW verification completed successfully");
        } catch Error(string memory reason) {
            console.log("KRW verification failed:", reason);
        } catch {
            console.log("KRW verification failed with unknown error");
        }
    }

    function _verifyNullifierRegistry(address registryAddress) internal {
        console.log("Verifying NullifierRegistry at:", registryAddress);

        // Constructor args: address _owner
        address owner = broadcaster;
        bytes memory constructorArgs = abi.encode(owner);

        string memory etherscanApiKey = vm.envString("ETHERSCAN_API_KEY");

        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(registryAddress);
        cmd[3] = "src/verifiers/nullifierRegistries/NullifierRegistry.sol:NullifierRegistry";
        cmd[4] = "--chain-id";
        cmd[5] = vm.toString(block.chainid);
        cmd[6] = "--constructor-args";
        cmd[7] = vm.toString(constructorArgs);
        cmd[8] = string.concat("--etherscan-api-key=", etherscanApiKey);

        console.log("Executing: forge verify-contract", vm.toString(registryAddress), "NullifierRegistry");

        try vm.ffi(cmd) returns (bytes memory result) {
            console.log("NullifierRegistry verification result:", string(result));
            console.log("NullifierRegistry verification completed successfully");
        } catch Error(string memory reason) {
            console.log("NullifierRegistry verification failed:", reason);
        } catch {
            console.log("NullifierRegistry verification failed with unknown error");
        }
    }

    function _verifyZkMinter(address zkMinterAddress, address tokenAddress) internal {
        console.log("Verifying ZkMinter at:", zkMinterAddress);

        // Constructor args: address _owner, address _token
        address owner = broadcaster;
        bytes memory constructorArgs = abi.encode(owner, tokenAddress);

        string memory etherscanApiKey = vm.envString("ETHERSCAN_API_KEY");

        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(zkMinterAddress);
        cmd[3] = "src/ZkMinter.sol:ZkMinter";
        cmd[4] = "--chain-id";
        cmd[5] = vm.toString(block.chainid);
        cmd[6] = "--constructor-args";
        cmd[7] = vm.toString(constructorArgs);
        cmd[8] = string.concat("--etherscan-api-key=", etherscanApiKey);

        console.log("Executing: forge verify-contract", vm.toString(zkMinterAddress), "ZkMinter");

        try vm.ffi(cmd) returns (bytes memory result) {
            console.log("ZkMinter verification result:", string(result));
            console.log("ZkMinter verification completed successfully");
        } catch Error(string memory reason) {
            console.log("ZkMinter verification failed:", reason);
        } catch {
            console.log("ZkMinter verification failed with unknown error");
        }
    }

    function _verifyTossBankReclaimVerifier(address verifierAddress, address zkMinterAddress, address nullifierRegistryAddress) internal {
        console.log("Verifying TossBankReclaimVerifier at:", verifierAddress);

        // Constructor args are complex for TossBankReclaimVerifier
        // Based on BaseTest.sol and deployment patterns:
        address owner = broadcaster;
        uint256 timestampBuffer = 60;
        bytes32[] memory witnessAddresses = new bytes32[](0);
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";

        bytes memory constructorArgs = abi.encode(
            owner,
            zkMinterAddress,
            nullifierRegistryAddress,
            timestampBuffer,
            witnessAddresses,
            providerHashes
        );

        string memory etherscanApiKey = vm.envString("ETHERSCAN_API_KEY");

        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(verifierAddress);
        cmd[3] = "src/verifiers/TossBankReclaimVerifier.sol:TossBankReclaimVerifier";
        cmd[4] = "--chain-id";
        cmd[5] = vm.toString(block.chainid);
        cmd[6] = "--constructor-args";
        cmd[7] = vm.toString(constructorArgs);
        cmd[8] = string.concat("--etherscan-api-key=", etherscanApiKey);

        console.log("Executing: forge verify-contract", vm.toString(verifierAddress), "TossBankReclaimVerifier");
        console.log("Note: TossBankReclaimVerifier has complex constructor args - verification may fail if args don't match deployment");

        try vm.ffi(cmd) returns (bytes memory result) {
            console.log("TossBankReclaimVerifier verification result:", string(result));
            console.log("TossBankReclaimVerifier verification completed");
        } catch Error(string memory reason) {
            console.log("TossBankReclaimVerifier verification failed:", reason);
        } catch {
            console.log("TossBankReclaimVerifier verification failed with unknown error");
        }
    }
}
