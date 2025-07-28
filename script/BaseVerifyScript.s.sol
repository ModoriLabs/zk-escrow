// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "script/Base.s.sol";

/**
 * @title BaseVerifyScript
 * @notice Base contract providing common functionality for contract verification scripts
 */
abstract contract BaseVerifyScript is BaseScript {

    /**
     * @notice Execute contract verification using forge verify-contract via vm.ffi
     * @param contractAddress Address of the deployed contract
     * @param contractPath Path to the contract source file and contract name (e.g., "src/Escrow.sol:Escrow")
     * @param constructorArgs ABI encoded constructor arguments
     * @param contractName Human readable contract name for logging
     */
    function _executeVerification(
        address contractAddress,
        string memory contractPath,
        bytes memory constructorArgs,
        string memory contractName
    ) internal {
        console.log(string.concat("Verifying ", contractName, " at:"), contractAddress);

        // Get Etherscan API key from environment
        string memory etherscanApiKey = vm.envString("ETHERSCAN_API_KEY");

        // Prepare forge verify-contract command
        string[] memory cmd = new string[](9);
        cmd[0] = "forge";
        cmd[1] = "verify-contract";
        cmd[2] = vm.toString(contractAddress);
        cmd[3] = contractPath;
        cmd[4] = "--chain-id";
        cmd[5] = vm.toString(block.chainid);
        cmd[6] = "--constructor-args";
        cmd[7] = vm.toString(constructorArgs);
        cmd[8] = string.concat("--etherscan-api-key=", etherscanApiKey);

        console.log(string.concat("Executing: forge verify-contract ", vm.toString(contractAddress), " ", contractName));
        console.log("Constructor args:", vm.toString(constructorArgs));

        // Execute verification command with error handling
        try vm.ffi(cmd) returns (bytes memory result) {
            console.log(string.concat(contractName, " verification result:"), string(result));
            console.log(string.concat(contractName, " verification completed successfully"));
        } catch Error(string memory reason) {
            console.log(string.concat(contractName, " verification failed:"), reason);
            _logVerificationFailureReasons();
        } catch {
            console.log(string.concat(contractName, " verification failed with unknown error"));
            _logVerificationFailureReasons();
        }
    }

    /**
     * @notice Log common reasons for verification failure
     */
    function _logVerificationFailureReasons() internal view {
        console.log("This might be due to:");
        console.log("1. Contract already verified");
        console.log("2. Constructor arguments mismatch");
        console.log("3. Network connectivity issues");
        console.log("4. Invalid Etherscan API key");
        console.log("Please check:");
        console.log("- Network connection");
        console.log("- Etherscan API key in environment");
        console.log("- Contract deployment status");
        console.log("- Constructor argument encoding");
    }

    /**
     * @notice Get chain name from chain ID
     * @param chainId The chain ID
     * @return Chain name string
     */
    function _getChainName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 1) return "mainnet";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 17000) return "holesky";
        if (chainId == 84532) return "basesep";
        if (chainId == 8453) return "base";
        if (chainId == 42161) return "arbitrum";
        if (chainId == 10) return "optimism";
        if (chainId == 137) return "polygon";
        if (chainId == 31337) return "anvil";
        return "unknown";
    }
}
