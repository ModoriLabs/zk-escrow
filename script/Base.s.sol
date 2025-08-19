// SPDX-License-Identifier: MIT
pragma solidity >=0.8.25 <0.9.0;

import { Script } from "forge-std/src/Script.sol";
import { console } from "forge-std/src/console.sol";
import { VmSafe } from "forge-std/src/Vm.sol";

abstract contract BaseScript is Script {
    /// @dev Included to enable compilation of the script without a $MNEMONIC environment variable.
    // string internal constant TEST_MNEMONIC = "test test test test test test test test test test test junk";
    uint256 internal PRIVATE_KEY;
    string internal networkName;

    /// @dev Needed for the deterministic deployments.
    bytes32 internal constant ZERO_SALT = bytes32(0);

    /// @dev The address of the transaction broadcaster.
    address internal broadcaster;

    /// @dev Used to derive the broadcaster's address if $ETH_FROM is not defined.
    string internal mnemonic;

    string internal deploymentFileSuffix = "-deploy.json";

    /// @dev Initializes the transaction broadcaster like this:
    ///
    /// - If $ETH_FROM is defined, use it.
    /// - Otherwise, derive the broadcaster address from $MNEMONIC.
    /// - If $MNEMONIC is not defined, default to a test mnemonic.
    ///
    /// The use case for $ETH_FROM is to specify the broadcaster key and its address via the command line.
    constructor() {
        if (block.chainid == 31337) {
            PRIVATE_KEY = vm.envOr("ANVIL_DEPLOYER_PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        } else if (block.chainid == 84532 || block.chainid == 1001) { // basesep, kairos
            PRIVATE_KEY = vm.envOr("TESTNET_PRIVATE_KEY", uint256(1));
        } else if (block.chainid == 8453 || block.chainid == 8217) { // base, kaia
            PRIVATE_KEY = vm.envOr("PROD_DEPLOYER_PRIVATE_KEY", uint256(1));
        } else {
            revert("Unknown chain");
        }
        broadcaster = vm.rememberKey(PRIVATE_KEY);
        console.log("Broadcaster: ", broadcaster);

        // networkName = vm.envString("NETWORK");
        // console.log("Network: ", networkName);
        // string memory rpcUrl = vm.envString("TEST_RPC_URL");
        // console.log("RPC URL: ", rpcUrl);
    }

    function parseAddress(string memory contractName) internal view returns(address payable contractAddress) {
        string memory path = string.concat(string.concat("./deployments/", networkName, "/"), contractName, ".json");
        string memory json = vm.readFile(path);
        bytes memory positionRouterAddressBytes = vm.parseJson(json, ".address");
        console.log("Contract: ", contractName);
        console.logBytes(positionRouterAddressBytes);
        contractAddress = abi.decode(positionRouterAddressBytes, (address));
    }

    function _writeDeployment(string memory contractName, address contractAddress) internal {
        string memory filePath = _getDeploymentPath(contractName);
        string memory jsonContent = string(
            abi.encodePacked(
                '{"address": "',
                contractAddress,
                '"}'
            )
        );
        vm.writeJson(jsonContent, filePath);
    }

    function _getDeploymentPath(string memory contractName) internal view returns (string memory) {
        return string.concat(string.concat("./deployments/", networkName, "/"), contractName, ".json");
    }

    /**
     * @dev Helper function to read contract address from deployments JSON file
     * @param contractName The name of the contract to get address for
     * @return The contract address for the current chain
     */
    function _getDeployedAddress(string memory contractName) internal view returns (address) {
        console.log("chainId", block.chainid);
        uint256 chainId = block.chainid;
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", vm.toString(chainId), deploymentFileSuffix);

        console.log("Reading deployment file:", path);

        try vm.readFile(path) returns (string memory json) {
            string memory key = string.concat(".", contractName);
            try vm.parseJsonAddress(json, key) returns (address contractAddress) {
                require(contractAddress != address(0), string.concat(contractName, " address not found in deployment file"));
                console.log(string.concat(contractName, " address:"), contractAddress);
                return contractAddress;
            } catch {
                console.log(string.concat("Failed to parse address for ", contractName, " from deployment file"));
                return address(0);
            }
        } catch {
            return address(0);
        }
    }

    /**
     * @dev Helper function to read owner address from config.json
     * @param chainId The chain ID to get owner for
     * @return owner The owner address for the specified chain
     */
    function _getOwnerFromConfig(uint256 chainId) internal view returns (address owner) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/config.json");

        console.log("Reading config file:", path);

        try vm.readFile(path) returns (string memory json) {
            string memory key = string.concat(".", vm.toString(chainId), ".owner");
            address ownerAddress = vm.parseJsonAddress(json, key);

            require(ownerAddress != address(0), string.concat("Owner address not found for chain ID: ", vm.toString(chainId)));
            console.log("Owner address from config:", ownerAddress);

            return ownerAddress;
        } catch {
            console.log("Failed to read config file or owner not found, using broadcaster as default");
            return broadcaster;
        }
    }

        /**
     * @dev Helper function to update deployment file with new contract address
     * @param contractName The name of the contract to update
     * @param contractAddress The address of the deployed contract
     */
    function _updateDeploymentFile(string memory contractName, address contractAddress) internal {
        if (!vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            return;
        }

        uint256 chainId = block.chainid;
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/", vm.toString(chainId), deploymentFileSuffix);

        // Read existing deployment file
        string memory existingJson = "{}";
        try vm.readFile(path) returns (string memory json) {
            existingJson = json;
        } catch {
            // File doesn't exist, use empty object
        }

        // Parse existing JSON and add/update the new contract
        string memory objectKey = "deployment";

        // Start with existing data
        vm.serializeJson(objectKey, existingJson);

        // Add/update the specific contract address
        string memory updatedJson = vm.serializeAddress(objectKey, contractName, contractAddress);

        // Write the updated deployment file with pretty formatting
        vm.writeJson(updatedJson, path);
        console.log("Updated deployment file:", path);
        console.log(string.concat("Added/Updated ", contractName, ":"), contractAddress);
    }

    function _getChainNameForEscrow(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 31337) return "anvil";
        if (chainId == 84532) return "basesep";
        if (chainId == 8453) return "base";
        if (chainId == 1001) return "kairos";
        if (chainId == 8217) return "kaia";
        // Add more chain mappings as needed
        revert("Unknown chain");
    }

    modifier broadcast() {
        vm.startBroadcast(broadcaster);
        _;
        vm.stopBroadcast();
    }
}
