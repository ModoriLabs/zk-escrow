// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/verifiers/TossBankReclaimVerifierV2.sol";
import "src/verifiers/nullifierRegistries/NullifierRegistry.sol";
import "src/verifiers/nullifierRegistries/INullifierRegistry.sol";
import "script/Base.s.sol";

contract DeployTossBankReclaimVerifierV2 is BaseScript {
    string public constant PROVIDER_HASH = "0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d";
    uint256 public timestampBuffer = 60;

    function run() external {
        address prevVerifier = _getDeployedAddress("TossBankReclaimVerifierV2");
        if (prevVerifier != address(0)) {
            console.log("TossBankReclaimVerifierV2 already deployed at:", prevVerifier);
            return; // Exit if already deployed
        }

        // Get required contract addresses from deployments
        address escrowAddress = _getDeployedAddress("Escrow");
        require(escrowAddress != address(0), "Escrow not deployed");

        address nullifierRegistryAddress = _getDeployedAddress("NullifierRegistry");
        require(nullifierRegistryAddress != address(0), "NullifierRegistry not deployed");

        vm.startBroadcast();
        address owner = broadcaster;

        // Prepare provider hashes
        string[] memory providerHashes = new string[](1);
        providerHashes[0] = PROVIDER_HASH;

        bytes32[] memory verifierCurrencies = new bytes32[](1);
        verifierCurrencies[0] = keccak256("KRW");

        // Deploy TossBankReclaimVerifierV2
        TossBankReclaimVerifierV2 verifier = new TossBankReclaimVerifierV2(
            owner,
            escrowAddress,
            INullifierRegistry(nullifierRegistryAddress),
            timestampBuffer,
            verifierCurrencies,
            providerHashes
        );

        console.log("TossBankReclaimVerifierV2 deployed to:", address(verifier));
        console.log("Owner:", owner);
        console.log("Escrow:", escrowAddress);
        console.log("NullifierRegistry:", nullifierRegistryAddress);
        console.log("Timestamp buffer:", timestampBuffer);

        vm.stopBroadcast();

        _updateDeploymentFile("TossBankReclaimVerifierV2", address(verifier));
    }
}
